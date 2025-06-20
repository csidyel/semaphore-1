require_relative "../base"
require "json"
require "fileutils"
require "time"
require "uri"

module GlobalReport
  class Aggregator < Base
    def initialize(reports_dir = "security-reports", output_dir = "global-security")
      @reports_dir = reports_dir
      @output_dir = output_dir
      @service_reports = {}
      @all_vulnerabilities = []
      @global_stats = {}

      FileUtils.mkdir_p(@output_dir)
    end

    def aggregate
      puts "🌍 Global Security Report Aggregator"
      puts "📁 Scanning reports in: #{@reports_dir}"
      puts

      load_service_reports

      if @service_reports.empty?
        puts "❌ No service reports found!"
        return
      end

      aggregate_data
      generate_global_summary

      puts "✅ Global security report generated!"
      print_global_stats
    end

    private

    def load_service_reports
      return unless Dir.exist?(@reports_dir)

      pattern = File.join(@reports_dir, "**", "*.json")
      report_files = Dir.glob(pattern)

      report_files.each do |file|
        puts "📊 Loading report from file: #{file}"
        begin
          job_id = File.basename(file, ".json")
          content = File.read(file)
          data = JSON.parse(content)

          # Extract both scan type and clean service name
          raw_service_name = data.dig("scan_summary", "service_name") || "no-service-name"
          scan_type = extract_scan_type_from_name(raw_service_name)
          service_name = extract_clean_service_name(raw_service_name)

          puts "   loading #{service_name} report (#{scan_type})"

          # Use service_name + scan_type as key to avoid conflicts
          report_key = "#{service_name}_#{scan_type}"

          @service_reports[report_key] = {
            service_name: service_name,
            scan_type: scan_type,
            job_id: job_id,
            file_path: file,
            data: data,
            last_modified: File.mtime(file),
            vulnerabilities: extract_vulnerabilities(data),
            summary: extract_summary(data),
          }
        rescue JSON::ParserError => e
          puts "   ⚠️  Invalid JSON in #{file}: #{e.message}"
        rescue => e
          puts "   ⚠️  Error loading #{file}: #{e.message}"
        end
      end

      puts "📈 Loaded #{@service_reports.length} scan reports"
      puts
    end

    def detect_scan_type(file_path, data)
      service_name = extract_service_name(data)

      # Extract scan type from service name pattern like "[docker] front" or "[dependencies] front"
      if service_name.match(/^\[([^\]]+)\]/)
        return $1.downcase
      end

      # Fallback to generic if no pattern found
      "security"
    end

    def extract_service_name(data)
      raw_name = data.dig("scan_summary", "service_name") || "no-service-name"
      extract_clean_service_name(raw_name)
    end

    def extract_vulnerabilities(data)
      return data["vulnerabilities"] if data["vulnerabilities"]
      return data["scan_summary"]["vulnerabilities"] if data.dig("scan_summary", "vulnerabilities")
      []
    end

    def extract_summary(data)
      return data["scan_summary"] if data["scan_summary"]

      # Build summary from vulnerability data
      vulns = extract_vulnerabilities(data)
      severity_counts = vulns.group_by { |v| v["severity"] }.transform_values(&:count)

      {
        "total_vulnerabilities" => vulns.length,
        "severity_counts" => severity_counts,
        "scan_date" => data["scan_date"] || Time.now.iso8601,
      }
    end

    def aggregate_data
      total_vulns = 0
      global_severity_counts = Hash.new(0)
      service_risk_levels = {}

      # Group reports by actual service name for risk calculation
      services_by_name = @service_reports.group_by { |_, report| report[:service_name] }

      services_by_name.each do |service_name, service_reports|
        service_vulns = []
        service_severity_counts = Hash.new(0)

        service_reports.each do |report_key, report|
          vulns = report[:vulnerabilities]
          summary = report[:summary]
          job_id = report[:job_id]
          scan_type = report[:scan_type]

          vulns.each do |v|
            v["service"] = service_name
            v["job_id"] = job_id
            v["scan_type"] = scan_type  # NEW: Add scan type to each vulnerability
          end

          service_vulns.concat(vulns)
          @all_vulnerabilities.concat(vulns)

          # Aggregate severity counts across all scan types for this service
          severity_counts = summary["severity_counts"] || {}
          severity_counts.each { |severity, count|
            global_severity_counts[severity] += count
            service_severity_counts[severity] += count
          }
        end

        # Calculate risk level based on combined vulnerabilities for the service
        critical_high = (service_severity_counts["CRITICAL"] || 0) + (service_severity_counts["HIGH"] || 0)
        service_risk_levels[service_name] = calculate_risk_level(critical_high, service_vulns.length)

        total_vulns += service_vulns.length
      end

      @global_stats = {
        total_services: services_by_name.length,  # Count unique service names
        total_vulnerabilities: total_vulns,
        severity_counts: global_severity_counts,
        service_risk_levels: service_risk_levels,
        scan_date: Time.now.iso8601,
        services_with_issues: services_by_name.count { |_, reports| reports.any? { |_, r| r[:vulnerabilities].any? } },
        clean_services: services_by_name.count { |_, reports| reports.all? { |_, r| r[:vulnerabilities].empty? } },
      }
    end

    def calculate_risk_level(critical_high_count, total_vulns)
      return "CLEAN" if total_vulns == 0
      return "CRITICAL" if critical_high_count >= 10
      return "HIGH" if critical_high_count >= 5
      return "MEDIUM" if critical_high_count >= 1
      return "LOW"
    end

    def generate_global_summary
      File.open(File.join(@output_dir, "global-security-summary.md"), "w") do |f|
        write_global_header(f)
        write_global_overview(f)
        write_service_breakdown(f)
        write_vulnerability_heatmap(f)
        write_top_vulnerabilities(f)
        write_complete_cve_list(f)
        write_detailed_cve_information(f)
        generate_github_issues_section(f)
        write_remediation_priorities(f)
        write_service_details(f)
      end
    end

    def write_global_header(f)
      f.puts "# 🌍 Global Security Dashboard"
      f.puts
      f.puts "**📅 Generated:** #{Time.now.strftime("%Y-%m-%d %H:%M:%S UTC")}"
      f.puts "**🏢 Total Services:** #{@global_stats[:total_services]}"
      f.puts "**🔍 Total Vulnerabilities:** #{@global_stats[:total_vulnerabilities]}"
      f.puts "**✅ Clean Services:** #{@global_stats[:clean_services]}"
      f.puts "**⚠️ Services with Issues:** #{@global_stats[:services_with_issues]}"
      f.puts
    end

    def write_global_overview(f)
      severity_counts = @global_stats[:severity_counts]
      critical_high = (severity_counts["CRITICAL"] || 0) + (severity_counts["HIGH"] || 0)

      f.puts "## 📊 Global Security Overview"
      f.puts

      # Risk assessment
      if @global_stats[:total_vulnerabilities] == 0
        f.puts "✅ **Excellent**: No security vulnerabilities detected across all services!"
      elsif critical_high == 0
        f.puts "🟡 **Good**: No critical or high severity vulnerabilities found."
      elsif critical_high <= 10
        f.puts "🟠 **Attention Needed**: #{critical_high} critical/high severity vulnerabilities across services."
      else
        f.puts "🔴 **Urgent Action Required**: #{critical_high} critical/high severity vulnerabilities need immediate attention!"
      end
      f.puts

      # Global severity breakdown
      f.puts "### Global Severity Distribution"
      f.puts
      f.puts "| Severity | Count | Services Affected |"
      f.puts "|----------|-------|-------------------|"

      ["CRITICAL", "HIGH", "MEDIUM", "LOW"].each do |severity|
        count = severity_counts[severity] || 0
        affected_services = count_services_with_severity(severity)
        emoji = severity_emoji(severity)
        f.puts "| #{emoji} **#{severity}** | #{count} | #{affected_services} |"
      end
      f.puts
    end

    def write_service_breakdown(f)
      f.puts "## 🏢 Service Risk Matrix"
      f.puts
      f.puts "| Service | Scan Types | Risk Level | Total Vulns | Critical | High | Medium | Low | Last Scan |"
      f.puts "|---------|------------|------------|-------------|----------|------|--------|-----|-----------|"

      # Group by service name and show scan types
      services_by_name = @service_reports.group_by { |_, report| report[:service_name] }

      sorted_services = services_by_name.sort_by do |service_name, reports|
        risk_weight = risk_level_weight(@global_stats[:service_risk_levels][service_name])
        total_vulns = reports.sum { |_, r| r[:vulnerabilities].length }
        [risk_weight, -total_vulns]
      end

      sorted_services.each do |service_name, reports|
        # Combine data from all scan types for this service
        all_vulns = reports.flat_map { |_, r| r[:vulnerabilities] }
        scan_types = reports.map { |_, r| r[:scan_type] }.sort.join(", ")

        combined_severity_counts = Hash.new(0)
        reports.each do |_, report|
          severity_counts = report[:summary]["severity_counts"] || {}
          severity_counts.each { |severity, count| combined_severity_counts[severity] += count }
        end

        risk_level = @global_stats[:service_risk_levels][service_name]
        total = all_vulns.length
        critical = combined_severity_counts["CRITICAL"] || 0
        high = combined_severity_counts["HIGH"] || 0
        medium = combined_severity_counts["MEDIUM"] || 0
        low = combined_severity_counts["LOW"] || 0

        last_scan = reports.map { |_, r| r[:last_modified] }.max.strftime("%Y-%m-%d")
        risk_emoji = risk_level_emoji(risk_level)

        f.puts "| #{job_link(service_name)} | #{scan_types} | #{risk_emoji} #{risk_level} | #{total} | #{critical} | #{high} | #{medium} | #{low} | #{last_scan} |"
      end
      f.puts
    end

    def write_vulnerability_heatmap(f)
      return if @all_vulnerabilities.empty?

      f.puts "## 🔥 Vulnerability Heatmap"
      f.puts

      # Most affected packages across all services
      package_vulns = @all_vulnerabilities.group_by { |v| v["location"] || "unknown" }
        .transform_values(&:length)
        .sort_by { |_, count| -count }
        .first(10)

      f.puts "### Most Vulnerable Packages (Top 10)"
      f.puts "| Package | Vulnerabilities | Services Affected |"
      f.puts "|---------|----------------|-------------------|"

      package_vulns.each do |package, count|
        services_affected = @all_vulnerabilities.select { |v| v["location"] == package }
          .map { |v| v["service"] }
          .uniq
          .length
        f.puts "| `#{package}` | #{count} | #{services_affected} |"
      end
      f.puts

      # Most common CVEs
      cve_counts = @all_vulnerabilities.group_by { |v| v["cve"] }
        .select { |cve, _| cve && !cve.empty? }
        .transform_values(&:length)
        .sort_by { |_, count| -count }
        .first(5)

      if cve_counts.any?
        f.puts "### Most Common CVEs (Top 5)"
        f.puts "| CVE | Occurrences | Services |"
        f.puts "|-----|-------------|----------|"

        cve_counts.each do |cve, count|
          services = @all_vulnerabilities.select { |v| v["cve"] == cve }
            .map { |v| v["service"] }
            .uniq
          f.puts "| `#{cve}` | #{count} | #{services.join(", ")} |"
        end
        f.puts
      end
    end

    def write_top_vulnerabilities(f)
      return if @all_vulnerabilities.empty?

      f.puts "## 🎯 Top Priority Vulnerabilities"
      f.puts

      top_vulns = @all_vulnerabilities.select { |v| ["CRITICAL", "HIGH"].include?(v["severity"]) }
        .sort_by do |v|
        cvss_score = extract_cvss_score(v)
        [-cvss_score, severity_weight(v["severity"])]
      end
        .first(10)

      if top_vulns.any?
        f.puts "| Service | Scan Type | CVE | Severity | CVSS | Package | Description |"
        f.puts "|---------|-----------|-----|----------|------|---------|-------------|"

        top_vulns.each do |vuln|
          service = vuln["service"] || "unknown"
          service_display = vuln["job_id"] ? "[#{service}](https://semaphore.semaphoreci.com/jobs/#{vuln["job_id"]})" : service
          scan_type = vuln["scan_type"] || "unknown"

          cve = vuln["cve"] || "N/A"
          severity = vuln["severity"] || "UNKNOWN"
          cvss = extract_cvss_score(vuln)
          cvss_display = cvss > 0 ? cvss.to_s : "N/A"
          package = vuln["location"] || "unknown"
          description = (vuln["title"] || vuln["description"] || "").slice(0, 50) + "..."

          emoji = severity_emoji(severity)
          f.puts "| #{service_display} | #{scan_type} | `#{cve}` | #{emoji} #{severity} | #{cvss_display} | `#{package}` | #{description} |"
        end
        f.puts
      end
    end

    def write_complete_cve_list(f)
      return if @all_vulnerabilities.empty?

      f.puts "## 📋 Complete CVE Inventory"
      f.puts

      # Get all unique CVEs with their details
      cve_details = {}
      @all_vulnerabilities.each do |vuln|
        cve = vuln["cve"]
        next unless cve && !cve.empty?

        if !cve_details[cve]
          cve_details[cve] = {
            cve: cve,
            severity: vuln["severity"],
            cvss_score: extract_cvss_score(vuln),
            title: vuln["title"] || vuln["description"] || "No description available",
            services: [],
            packages: [],
            occurrences: 0,
            fixed_versions: [],
          }
        end

        cve_details[cve][:services] << vuln["service"] if vuln["service"]
        cve_details[cve][:packages] << vuln["location"] if vuln["location"]
        cve_details[cve][:fixed_versions] << vuln["fixed_version"] if vuln["fixed_version"]
        cve_details[cve][:occurrences] += 1

        # Use highest severity if multiple found
        current_severity_weight = severity_weight(cve_details[cve][:severity])
        new_severity_weight = severity_weight(vuln["severity"])
        if new_severity_weight < current_severity_weight
          cve_details[cve][:severity] = vuln["severity"]
        end

        # Use highest CVSS score if multiple found
        new_cvss = extract_cvss_score(vuln)
        if new_cvss > cve_details[cve][:cvss_score]
          cve_details[cve][:cvss_score] = new_cvss
        end
      end

      # Clean up duplicates
      cve_details.each do |cve, details|
        details[:services] = details[:services].uniq.sort
        details[:packages] = details[:packages].uniq.sort
        details[:fixed_versions] = details[:fixed_versions].uniq.compact
      end

      # Sort by severity and CVSS score
      sorted_cves = cve_details.values.sort_by do |details|
        [-details[:cvss_score], severity_weight(details[:severity]), details[:cve]]
      end

      f.puts "**📊 Summary:** #{cve_details.length} unique CVEs found across #{@global_stats[:total_services]} services"
      f.puts

      # Statistics breakdown
      severity_breakdown = sorted_cves.group_by { |cve| cve[:severity] }.transform_values(&:length)
      f.puts "**Severity Distribution:**"
      ["CRITICAL", "HIGH", "MEDIUM", "LOW"].each do |severity|
        count = severity_breakdown[severity] || 0
        next if count == 0
        emoji = severity_emoji(severity)
        f.puts "- #{emoji} #{severity}: #{count} CVEs"
      end
      f.puts

      # CVE table
      f.puts "| CVE | Severity | CVSS | Services | Packages | Occurrences | Fix Available |"
      f.puts "|-----|----------|------|----------|----------|-------------|---------------|"

      sorted_cves.each do |details|
        cve = details[:cve]
        severity = details[:severity]
        cvss = details[:cvss_score] > 0 ? details[:cvss_score].to_s : "N/A"
        services = details[:services].length > 3 ? "#{details[:services][0..2].join(", ")}... (#{details[:services].length})" : details[:services].join(", ")
        packages = details[:packages].length > 2 ? "#{details[:packages][0..1].join(", ")}... (#{details[:packages].length})" : details[:packages].join(", ")
        occurrences = details[:occurrences]
        fix_available = details[:fixed_versions].any? ? "✅ Yes" : "❌ No"

        emoji = severity_emoji(severity)

        f.puts "| `#{cve}` | #{emoji} #{severity} | #{cvss} | #{services} | #{packages} | #{occurrences} | #{fix_available} |"
      end
      f.puts

      # Additional CVE insights
      f.puts "### 🔍 CVE Insights"
      f.puts

      # Cross-service CVEs
      cross_service_cves = cve_details.select { |_, details| details[:services].length > 1 }
      if cross_service_cves.any?
        f.puts "**🌐 Cross-Service CVEs** (affecting multiple services):"
        cross_service_cves.sort_by { |_, details| -details[:services].length }.first(10).each do |cve, details|
          emoji = severity_emoji(details[:severity])
          f.puts "- #{emoji} `#{cve}`: #{details[:services].length} services (#{details[:services].join(", ")})"
        end
        f.puts
      end

      # High-impact CVEs
      high_impact_cves = cve_details.select { |_, details| details[:cvss_score] >= 9.0 }
      if high_impact_cves.any?
        f.puts "**⚠️ Critical CVSS CVEs** (CVSS ≥ 9.0):"
        high_impact_cves.sort_by { |_, details| -details[:cvss_score] }.each do |cve, details|
          f.puts "- 🔴 `#{cve}`: CVSS #{details[:cvss_score]} - #{details[:title].slice(0, 80)}..."
        end
        f.puts
      end

      # Fixable CVEs
      fixable_cves = cve_details.select { |_, details| details[:fixed_versions].any? }
      if fixable_cves.any?
        f.puts "**🔧 Fixable CVEs** (#{fixable_cves.length}/#{cve_details.length}):"
        f.puts "These CVEs have available fixes and should be prioritized for remediation."
        f.puts
      end
    end

    def write_remediation_priorities(f)
      f.puts "## 💡 Remediation Priorities"
      f.puts

      critical_services = @global_stats[:service_risk_levels].select { |_, level| level == "CRITICAL" }
      high_risk_services = @global_stats[:service_risk_levels].select { |_, level| level == "HIGH" }

      f.puts "### Immediate Actions (Next 24-48 hours)"
      if critical_services.any?
        f.puts "🔴 **Critical Services** (#{critical_services.length}):"
        critical_services.keys.each { |service| f.puts "- `#{service}`: Focus on CRITICAL and HIGH severity vulnerabilities" }
      else
        f.puts "✅ No services in critical state"
      end
      f.puts

      f.puts "### Short-term Actions (Next 1-2 weeks)"
      if high_risk_services.any?
        f.puts "🟠 **High Risk Services** (#{high_risk_services.length}):"
        high_risk_services.keys.each { |service| f.puts "- `#{service}`: Address HIGH severity vulnerabilities" }
      else
        f.puts "✅ No services in high risk state"
      end
      f.puts

      # Actionable recommendations
      total_fixable = @all_vulnerabilities.count { |v| v["fixed_version"] && !v["fixed_version"].empty? }
      unique_cves = @all_vulnerabilities.map { |v| v["cve"] }.compact.uniq.length
      f.puts "### Quick Wins"
      f.puts "- 🔧 **#{total_fixable} vulnerabilities** have available fixes"
      f.puts "- 📊 Focus on packages appearing in multiple services"
      f.puts "- 🎯 Prioritize vulnerabilities with CVSS scores ≥ 7.0"
      f.puts "- 📋 **#{unique_cves} unique CVEs** identified (see complete list above)"
      f.puts
    end

    def write_service_details(f)
      f.puts "## 📋 Service Details"
      f.puts

      # Group by service name to show all scan types together
      services_by_name = @service_reports.group_by { |_, report| report[:service_name] }

      services_by_name.each do |service_name, reports|
        # Combine all vulnerabilities from all scan types for this service
        all_vulns = reports.flat_map { |_, r| r[:vulnerabilities] }

        if all_vulns.empty?
          f.puts "### ✅ #{service_name}"
          f.puts "No vulnerabilities detected across all scan types."
          f.puts
          next
        end

        # Calculate combined stats
        combined_severity_counts = Hash.new(0)
        reports.each do |_, report|
          severity_counts = report[:summary]["severity_counts"] || {}
          severity_counts.each { |severity, count| combined_severity_counts[severity] += count }
        end

        risk_level = @global_stats[:service_risk_levels][service_name]
        most_recent_scan = reports.map { |_, r| r[:last_modified] }.max

        f.puts "### #{risk_level_emoji(risk_level)} #{job_link(service_name)}"
        f.puts "**Total Vulnerabilities:** #{all_vulns.length}  "
        f.puts "**Risk Level:** #{risk_level}  "
        f.puts "**Last Scan:** #{most_recent_scan.strftime('%Y-%m-%d %H:%M')}"

        # Show scan types breakdown
        f.puts "**Scan Types:**"
        reports.each do |_, report|
          scan_type = report[:scan_type]
          scan_vulns = report[:vulnerabilities]
          scan_severity_counts = report[:summary]["severity_counts"] || {}

          f.puts "- **#{scan_type.capitalize}**: #{scan_vulns.length} vulnerabilities"
          if scan_vulns.any?
            critical = scan_severity_counts["CRITICAL"] || 0
            high = scan_severity_counts["HIGH"] || 0
            medium = scan_severity_counts["MEDIUM"] || 0
            low = scan_severity_counts["LOW"] || 0
            f.puts "  - 🔴 #{critical} Critical, 🟠 #{high} High, 🟡 #{medium} Medium, 🔵 #{low} Low"
          end
        end

        # CVE count for this service (across all scan types)
        service_cves = all_vulns.map { |v| v["cve"] }.compact.uniq
        f.puts "**Unique CVEs:** #{service_cves.length}"
        f.puts

        # Top issues for this service (across all scan types)
        top_issues = all_vulns.select { |v| ["CRITICAL", "HIGH"].include?(v["severity"]) }
                              .sort_by { |v| [-extract_cvss_score(v), severity_weight(v["severity"])] }
                              .first(5)

        if top_issues.any?
          f.puts "**Top Issues:**"
          top_issues.each do |issue|
            emoji = severity_emoji(issue["severity"])
            scan_type_badge = "[#{issue["scan_type"]}]"
            f.puts "- #{emoji} `#{issue["cve"]}` in `#{issue["location"]}` #{scan_type_badge}"
          end
        end
        f.puts
      end
    end

    # Helper methods
    def count_services_with_severity(severity)
      @service_reports.count do |_, report|
        severity_counts = report[:summary]["severity_counts"] || {}
        (severity_counts[severity] || 0) > 0
      end
    end

    def risk_level_weight(level)
      {
        "CRITICAL" => 0,
        "HIGH" => 1,
        "MEDIUM" => 2,
        "LOW" => 3,
        "CLEAN" => 4,
      }[level] || 5
    end

    def print_global_stats
      puts "🌍 Global Security Report Summary:"
      puts "   🏢 Services Analyzed: #{@global_stats[:total_services]}"
      puts "   🔍 Total Vulnerabilities: #{@global_stats[:total_vulnerabilities]}"
      puts "   ✅ Clean Services: #{@global_stats[:clean_services]}"
      puts "   ⚠️  Services with Issues: #{@global_stats[:services_with_issues]}"
      puts
      puts "📊 Global Severity Breakdown:"
      severity_counts = @global_stats[:severity_counts]
      puts "   🔴 Critical: #{severity_counts["CRITICAL"] || 0}"
      puts "   🟠 High:     #{severity_counts["HIGH"] || 0}"
      puts "   🟡 Medium:   #{severity_counts["MEDIUM"] || 0}"
      puts "   🔵 Low:      #{severity_counts["LOW"] || 0}"

      # CVSS stats
      cvss_scores = @all_vulnerabilities.map { |v| extract_cvss_score(v) }.select { |s| s > 0 }
      if cvss_scores.any?
        puts "   🎯 Avg CVSS: #{(cvss_scores.sum.to_f / cvss_scores.length).round(1)}/10.0"
        puts "   📈 Max CVSS: #{cvss_scores.max}/10.0"
      end

      # CVE insights
      unique_cves = @all_vulnerabilities.map { |v| v["cve"] }.compact.uniq.length
      fixable_count = @all_vulnerabilities.count { |v| v["fixed_version"] && !v["fixed_version"].empty? }
      puts
      puts "🔍 Additional Insights:"
      puts "   📋 Unique CVEs: #{unique_cves}"
      puts "   🔧 Fixable Vulnerabilities: #{fixable_count}"
      puts "   📦 Vulnerable Packages: #{@all_vulnerabilities.map { |v| v["location"] }.compact.uniq.length}"
      puts
      puts "📁 Generated Report:"
      puts "   📄 global-security-summary.md - Complete detailed report with CVE inventory and detailed CVE information"
      puts
      puts "💡 The global report now contains a complete CVE inventory with all vulnerability details!"
    end

    def write_detailed_cve_information(f)
      return if @all_vulnerabilities.empty?

      f.puts "## 📖 Detailed CVE Information"
      f.puts

      # Get all unique CVEs with full details
      cve_full_details = {}
      @all_vulnerabilities.each do |vuln|
        cve = vuln["cve"]
        next unless cve && !cve.empty?

        if !cve_full_details[cve]
          cve_full_details[cve] = vuln.dup
          cve_full_details[cve]["all_services"] = []
          cve_full_details[cve]["all_packages"] = []
          cve_full_details[cve]["all_targets"] = []
        end

        cve_full_details[cve]["all_services"] << vuln["service"] if vuln["service"]
        cve_full_details[cve]["all_packages"] << vuln["location"] if vuln["location"]
        cve_full_details[cve]["all_targets"] << vuln["target"] if vuln["target"]
      end

      # Clean up duplicates and sort by severity/CVSS
      cve_full_details.each do |cve, details|
        details["all_services"] = details["all_services"].uniq.sort
        details["all_packages"] = details["all_packages"].uniq.sort
        details["all_targets"] = details["all_targets"].uniq.sort
      end

      sorted_cves = cve_full_details.values.sort_by do |details|
        cvss_score = extract_cvss_score(details)
        [-cvss_score, severity_weight(details["severity"]), details["cve"]]
      end

      f.puts "**Total Detailed CVEs:** #{sorted_cves.length}"
      f.puts

      sorted_cves.each_with_index do |cve_data, index|
        write_single_cve_detail(f, cve_data, index + 1)
      end
    end

    def write_single_cve_detail(f, cve_data, index)
      cve = cve_data["cve"]
      severity = cve_data["severity"] || "UNKNOWN"
      emoji = severity_emoji(severity)

      services_with_links = cve_data["all_services"].map do |service|
        vuln_with_job = @all_vulnerabilities.find { |v| v["service"] == service }
        if vuln_with_job && vuln_with_job["job_id"]
          "[#{service}](https://semaphore.semaphoreci.com/jobs/#{vuln_with_job["job_id"]})"
        else
          service
        end
      end

      f.puts "### #{index}. #{emoji} #{cve}"
      f.puts

      # Basic information table
      f.puts "| Field | Value |"
      f.puts "|-------|-------|"
      f.puts "| **CVE ID** | `#{cve}` |"
      f.puts "| **Severity** | #{emoji} #{severity} |"

      # CVSS information
      if cve_data["cvss"]
        cvss = cve_data["cvss"]
        if cvss["v3_score"]
          f.puts "| **CVSS v3 Score** | #{cvss["v3_score"]}/10.0 |"
          f.puts "| **CVSS v3 Vector** | `#{cvss["v3_vector"]}` |" if cvss["v3_vector"]
        elsif cvss["v2_score"]
          f.puts "| **CVSS v2 Score** | #{cvss["v2_score"]}/10.0 |"
          f.puts "| **CVSS v2 Vector** | `#{cvss["v2_vector"]}` |" if cvss["v2_vector"]
        end
      end

      f.puts "| **Detections** | #{cve_data["all_services"].join(", ")} |"
      f.puts "| **Affected Services** | #{services_with_links.join(", ")} |"
      f.puts "| **Affected Packages** | #{cve_data["all_packages"].join(", ")} |"
      f.puts "| **Targets** | #{cve_data["all_targets"].join(", ")} |" if cve_data["all_targets"].any?
      f.puts "| **Fixed Version** | `#{cve_data["fixed_version"]}` |" if cve_data["fixed_version"]
      f.puts "| **Installed Version** | `#{cve_data["installed_version"]}` |" if cve_data["installed_version"]
      f.puts "| **Published Date** | #{cve_data["published_date"]} |" if cve_data["published_date"]
      f.puts "| **Last Modified** | #{cve_data["last_modified_date"]} |" if cve_data["last_modified_date"]
      f.puts "| **Data Source** | #{cve_data["data_source"]} |" if cve_data["data_source"]
      f.puts

      # Title and Description
      if cve_data["title"] && !cve_data["title"].empty?
        f.puts "**📋 Title:**"
        f.puts "> #{cve_data["title"]}"
        f.puts
      end

      if cve_data["description"] && !cve_data["description"].empty?
        f.puts "**📝 Description:**"
        f.puts "> #{cve_data["description"]}"
        f.puts
      end

      # References
      if cve_data["references"] && cve_data["references"].any?
        f.puts "**🔗 References:**"
        cve_data["references"].each do |ref|
          if ref.match?(/^https?:\/\//)
            # It's already a URL, make it clickable
            f.puts "- [#{ref}](#{ref})"
          elsif ref.include?("://") || ref.start_with?("www.")
            # It's a URL but missing protocol, add https://
            clean_url = ref.start_with?("www.") ? "https://#{ref}" : ref
            f.puts "- [#{ref}](#{clean_url})"
          else
            # Not a URL, display as text
            f.puts "- #{ref}"
          end
        end
        f.puts
      end

      # Package path information
      if cve_data["pkg_path"] && !cve_data["pkg_path"].empty?
        f.puts "**📦 Package Path:** `#{cve_data["pkg_path"]}`"
        f.puts
      end

      f.puts "---"
      f.puts
    end

    def generate_github_issues_section(f)
      return if @all_vulnerabilities.empty?

      f.puts "## 🎫 GitHub Issue Links"
      f.puts
      f.puts "**Click the links below to create GitHub issues (one per CVE/service pair):**"
      f.puts

      # Create individual entries for each CVE/service combination
      issue_links = []

      @all_vulnerabilities.each do |vuln|
        cve = vuln["cve"]
        service = vuln["service"]

        next unless cve && !cve.empty? && service && !service.empty?

        # Create unique identifier for this CVE/service pair
        pair_id = "#{cve}_#{service}"

        # Skip if we've already processed this exact pair
        next if issue_links.any? { |link| link[:pair_id] == pair_id }

        # Create the GitHub issue link with pre-filled data
        title = "Vulnerability Report - #{cve} #{service}"
        body = generate_prefilled_issue_body(vuln)

        github_url = build_github_issue_url(title, body)

        severity_emoji = severity_emoji(vuln["severity"])

        issue_links << {
          pair_id: pair_id,
          cve: cve,
          service: service,
          severity: vuln["severity"],
          severity_weight: severity_weight(vuln["severity"]),
          emoji: severity_emoji,
          url: github_url,
        }
      end

      # Sort by severity, then by CVE, then by service
      issue_links.sort_by! { |link| [link[:severity_weight], link[:cve], link[:service]] }

      # Generate the links
      issue_links.each do |link|
        f.puts "- #{link[:emoji]} [#{link[:cve]} - #{link[:service]}](#{link[:url]}) (#{link[:severity]})"
      end
      f.puts
    end

    def build_github_issue_url(title, body)
      base_url = "https://github.com/renderedtext/tasks/issues/new"
      template = "processing-vulnerability-report.md"

      # Try different encoding approach
      encoded_title = URI.encode_uri_component(title)
      # Don't encode the body, let GitHub handle it
      encoded_body = URI.encode_uri_component(body)

      "#{base_url}?template=#{template}&title=#{encoded_title}&body=#{encoded_body}"
    end

    def generate_prefilled_issue_body(vuln)
      severity = map_severity_to_github_format(vuln["severity"])
      detected_date = Date.today.strftime("%Y-%m-%d")

      job_url = vuln["job_id"] ? "https://semaphore.semaphoreci.com/jobs/#{vuln["job_id"]}" : "[TODO - Add security scan job URL]"

      # Build the pre-filled body
      body = <<~BODY
        ## Vulnerability Details
        - **Identifier**: #{vuln["cve"]}
        - **Service Affected**: #{vuln["service"]}
        - **Detected On**: #{detected_date}
        - **CI Job URL**: #{job_url}
        - **Severity**: #{severity}

        ## Description
        #{vuln["title"] || vuln["description"] || "Please add vulnerability description"}

        **Package:** #{vuln["location"]}
        **Installed Version:** #{vuln["installed_version"]}
        **Fixed Version:** #{vuln["fixed_version"] || "Not available"}
        **CVSS Score:** #{extract_cvss_display(vuln)}

        ## SOC2 - Compliance Checklist (Engineering)
        *SOC 2 Compliance Checklist to be completed by Engineers while the task is addressed*
        - [x] ~Security Requirements~
        - [ ] Link to the PR
          - TODO
        - [ ] Link to the Production PR in Launchpad
          - TODO
        - [x] ~Feature was enabled (when we enable a feature via Feature Flag)~
        - [ ] Post-implementation functional and security testing report (test plan should be prepared during Design and Architecture phases)
      BODY

      body.strip
    end

    def extract_cvss_display(vuln)
      return "N/A" unless vuln["cvss"]

      cvss = vuln["cvss"]
      if cvss["v3_score"]
        "#{cvss["v3_score"]}/10.0 (v3)"
      elsif cvss["v2_score"]
        "#{cvss["v2_score"]}/10.0 (v2)"
      else
        "N/A"
      end
    end

    def map_severity_to_github_format(severity)
      case severity&.upcase
      when "CRITICAL"
        "Critical"
      when "HIGH"
        "Critical"
      when "MEDIUM"
        "Moderate"
      when "LOW"
        "Low"
      else
        "Moderate"
      end
    end

    def job_link(service_name)
      # Find any report for this service to get a job_id
      service_report = @service_reports.values.find { |report| report[:service_name] == service_name }
      return service_name unless service_report && service_report[:job_id]

      job_url = "https://semaphore.semaphoreci.com/jobs/#{service_report[:job_id]}"
      "[#{service_name}](#{job_url})"
    end
  end
end
