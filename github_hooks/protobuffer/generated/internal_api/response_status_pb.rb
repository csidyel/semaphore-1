# frozen_string_literal: true
# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: internal_api/response_status.proto

require 'google/protobuf'


descriptor_data = "\n\"internal_api/response_status.proto\x12\x0bInternalApi\"p\n\x0eResponseStatus\x12.\n\x04\x63ode\x18\x01 \x01(\x0e\x32 .InternalApi.ResponseStatus.Code\x12\x0f\n\x07message\x18\x02 \x01(\t\"\x1d\n\x04\x43ode\x12\x06\n\x02OK\x10\x00\x12\r\n\tBAD_PARAM\x10\x01\x42\x11Z\x0fresponse_statusb\x06proto3"

pool = Google::Protobuf::DescriptorPool.generated_pool
pool.add_serialized_file(descriptor_data)

module InternalApi
  ResponseStatus = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("InternalApi.ResponseStatus").msgclass
  ResponseStatus::Code = ::Google::Protobuf::DescriptorPool.generated_pool.lookup("InternalApi.ResponseStatus.Code").enummodule
end
