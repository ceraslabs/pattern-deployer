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
    class PatternDeployerError < StandardError
      def initialize(message, error_type, http_error_code, inner_exception = nil)
        super(message)
        @error_type = error_type
        @http_error_code = http_error_code
        @inner_exception = inner_exception
      end

      def error_type
        @error_type
      end

      def http_error_code
        @http_error_code
      end

      def get_inner_exception
        @inner_exception
      end
    end

    class ParametersValidationError < PatternDeployerError
      DEFAULT_MSG = "The request parameter(s) is/are invalid"

      def initialize(options = {})
        message = DEFAULT_MSG
        message = options[:message] if options[:message]
        message = options[:ar_obj].errors.full_messages.join(";") if options[:ar_obj]

        super(message, self.class.name.demodulize, 400, options[:inner_exception])
      end
    end

    class InvalidUrlError < PatternDeployerError
      DEFAULT_MSG = "The request url doesnot match to any resources"

      def initialize(options = {})
        message = DEFAULT_MSG
        message = options[:message] if options[:message]
        super(message, self.class.name.demodulize, 404, options[:inner_exception])
      end
    end

    class XmlValidationError < PatternDeployerError
      DEFAULT_MSG = "The request xml document is invalid"

      def initialize(options = {})
        message = DEFAULT_MSG
        message = options[:message] if options[:message]
        message = options[:ar_obj].errors.full_messages.join(";") if options[:ar_obj]

        super(message, self.class.name.demodulize, 400, options[:inner_exception])
      end
    end

    class DeploymentError < PatternDeployerError
      DEFAULT_MSG = "Deployment failed, please check the logs for details"

      def initialize(options = {})
        message = DEFAULT_MSG
        message = options[:message] if options[:message]

        if options[:std_err]
          message += "Capture output:"
          message += "\n=================================================\n"
          message += options[:std_err]
          message += "\n=================================================\n"
        end

        @inner_message = options[:inner_message]

        super(message, self.class.name.demodulize, 400, options[:inner_exception])
      end

      def get_inner_message
        @inner_message
      end
    end

    class AccessDeniedError < PatternDeployerError
      DEFAULT_MSG = "Permission denied, please contact the site admin to grant you permissions"

      def initialize(options = {})
        message = DEFAULT_MSG
        message = options[:message] if options[:message]

        super(message, self.class.name.demodulize, 403, options[:inner_exception])
      end
    end

    class InternalServerError < PatternDeployerError
      DEFAULT_MSG = "Unexpected error"

      def initialize(options = {})
        message = DEFAULT_MSG
        message = options[:message] if options[:message]

        super(message, self.class.name.demodulize, 500, options[:inner_exception])
      end
    end

  end
end