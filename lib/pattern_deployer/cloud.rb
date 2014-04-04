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
require 'pattern_deployer/errors'

module PatternDeployer
  module Cloud
    module ClassMethods
      def ec2?(cloud)
        cloud && cloud.downcase == EC2
      end

      def openstack?(cloud)
        cloud && cloud.downcase == OPENSTACK
      end

      def cloud_unspecified?(cloud)
        cloud.nil? || cloud.downcase == UNSPECIFIED
      end

      def validate_cloud(cloud)
        ec2?(cloud) || openstack?(cloud) || cloud_unspecified?(cloud)
      end

      def validate_cloud!(cloud)
        unless validate_cloud(cloud)
          msg = "The cloud '#{cloud}' is incorrect or unsupported. "
          msg << "The list of supported clouds are #{Rails.application.config.supported_clouds.inspect}."
          raise XmlValidationError.new(:message => msg)
        end
      end
    end

    EC2 = Rails.application.config.ec2
    OPENSTACK = Rails.application.config.openstack
    UNSPECIFIED = Rails.application.config.cloud_unspecified

    def self.included(base)
      base.extend(ClassMethods)
    end

  end
end