# frozen_string_literal: true
module Monarchy
  module Exceptions
    class Error < StandardError; end

    class RoleNotExist < Error
      def initialize(role_name)
        @role_name = role_name
      end

      def message
        "Role '#{@role_name}' does not exist"
      end
    end

    class ModelNotResource < Error
      def initialize(resource)
        @resource = resource
      end

      def message
        "Model '#{@resource.class}' is not acting as resource!"
      end
    end

    class ResourceIsNil < Error
      def message
        "Resource can NOT be nil!"
      end
    end
  end
end