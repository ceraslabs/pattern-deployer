#
# Copyright 2013 Marin Litoiu, Hongbin Lu, Mark Shtern, Bradlley Simmons, Mike
# Smit
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
module PatternDeployer
  module Errors
    class PatternDeployerError < StandardError; end

    class ApiError < PatternDeployerError
      attr_accessor :error_type, :http_error_code

      def initialize(message, http_error_code)
        super(message)
        self.http_error_code = http_error_code
        self.error_type = self.class.name.demodulize
      end

      def self.create(error)
        bad_request = new(error.message)
        bad_request.set_backtrace(error.backtrace)
        bad_request.error_type = error.class.name.demodulize if error.kind_of?(PatternDeployerError)
        bad_request
      end
    end

    class BadRequestError < ApiError
      def initialize(message)
        super(message, 400)
      end
    end

    class AccessDeniedError < ApiError
      DEFAULT_MSG = "Permission denied."

      def initialize(message = DEFAULT_MSG)
        super(message, 403)
      end
    end

    class InvalidUrlError < ApiError
      def initialize(message)
        super(message, 404)
      end
    end

    class InternalServerError < ApiError
      def initialize(message)
        super(message, 500)
      end
    end

    class DeploymentError < PatternDeployerError
      attr_accessor :remote_exception

      DEFAULT_MSG = "Deployment failed."

      def initialize(message = DEFAULT_MSG)
        super(message)
      end
    end

    class DeploymentTimeOutError < PatternDeployerError
      DEFAULT_MSG = "Deployment timeout."

      def initialize(message = DEFAULT_MSG)
        super(message)
      end
    end

    class InvalidOperationError < PatternDeployerError; end

    class NotFoundError < PatternDeployerError; end

    class PatternValidationError < PatternDeployerError; end

    class ParametersValidationError < PatternDeployerError
      attr_accessor :active_record

      DEFAULT_MSG = "The request parameter(s) is/are invalid."

      def initialize(message = DEFAULT_MSG)
        super(message)
      end

      def message
        message = super
        message << "\n"
        message << active_record.errors.full_messages.join(";") if active_record
        message
      end
    end

    class RemoteError < PatternDeployerError; end

  end
end