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
require 'pattern_deployer/pattern/config'

module PatternDeployer
  module Pattern
    class DatabaseConfig
      CONFIG_SPECS = [
        {
          element:        'service',
          key:            'database',
          child_elements: ['database_system', 'database_name', 'database_user', 'database_password', 'database_port', 'script']
        },
        {
          element:        'database_system',
          key:            'system',
          default_value:  'mysql',
          allow_values:   ['mysql', 'postgresql']
        },
        {
          element:        'database_name',
          key:            'name',
          default_value:  'mydb'
        },
        {
          element:        'database_user',
          key:            'user',
          default_value:  'myuser'
        },
        {
          element:        'database_password',
          key:            'password',
          default_value:  'mypass'
        },
        {
          element:        'database_port',
          key:            'port',
        },
        {
          element:        'script',
          key:            'script'
        }
      ]

      def self.get(element)
        configs = Config::parse_configs(element.name, CONFIG_SPECS, element)
        case configs['database']['system']
        when 'mysql'
          configs['database']['port'] ||= '3306'
          configs['database']['admin_user'] = 'root'
        when 'postgresql'
          configs['database']['port'] ||= '5432'
          configs['database']['admin_user'] = 'postgres'
        else
          # should not be reached
        end
        new(configs)
      end

      def initialize(configs)
        @configs = configs
      end

      def to_hash
        @configs
      end

      def db_script_file
        {'name' => @configs['database']['script']}
      end

    end
  end
end