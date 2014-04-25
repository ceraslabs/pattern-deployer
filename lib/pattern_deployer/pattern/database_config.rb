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
    class DatabaseConfig < PatternDeployer::Pattern::Config
      CONFIG_SPECS = [
        {
          element_name:   "service",
          name:           "database",
          child_elements: ["database_system", "database_name", "database_user", "database_password", "database_port", "script"]
        },
        {
          element_name:   "database_system",
          name:           "system",
          default_value:  "mysql",
          allow_values:   ["mysql", "postgresql"]
        },
        {
          element_name:   "database_name",
          name:           "name",
          default_value:  "mydb"
        },
        {
          element_name:   "database_user",
          name:           "user",
          default_value:  "myuser"
        },
        {
          element_name:   "database_password",
          name:           "password",
          default_value:  "mypass"
        },
        {
          element_name:   "database_port",
          name:           "port",
        },
        {
          element_name:   "script",
          name:           "script"
        }
      ]

      def self.get(element)
        spec = ConfigSpec.new(CONFIG_SPECS, element.name)
        configs = parse_configs(element, spec)
        case configs["database"]["system"]
        when "mysql"
          configs["database"]["port"] ||= "3306"
          configs["database"]["admin_user"] = "root"
        when "postgresql"
          configs["database"]["port"] ||= "5432"
          configs["database"]["admin_user"] = "postgres"
        else
          fail "Unexpected database system '#{configs["database"]["system"]}'."
        end
        new(configs)
      end

      def db_script_file
        {"name" => @configs["database"]["script"]}
      end

    end
  end
end