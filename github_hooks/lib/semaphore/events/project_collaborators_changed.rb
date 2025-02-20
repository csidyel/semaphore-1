module Semaphore::Events
  class ProjectCollaboratorsChanged

    def self.emit(project)
      msg_klass = InternalApi::Projecthub::CollaboratorsChanged

      event = msg_klass.new(
        :project_id => project.id,
        :timestamp => ::Google::Protobuf::Timestamp.new(:seconds => Time.now.to_i)
      )

      message = msg_klass.encode(event)

      options = {
        :exchange => "project_exchange",
        :routing_key => "collaborators_changed",
        :url => App.amqp_url
      }

      Logman.info "Publishing project collaborators changed event for project #{project.id}"

      Tackle.publish(message, options)
    end
  end
end
