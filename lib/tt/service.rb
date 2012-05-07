
require 'active_support/core_ext/string/inflections'

module TimeTracker
  module Service
    class Error < StandardError
      attr_reader :response, :message
      def initialize(response, message)
        @response = response
        @message = message
      end
    end
    class UnauthorizedError < Error; end
    class ResourceNotFoundError < Error; end
    class ResourceInvalidError < Error; end
    class InternalError < Error; end

    def self.get_service(service_name)
      TimeTracker::Service.const_get(service_name.classify)
    end
  end
end
