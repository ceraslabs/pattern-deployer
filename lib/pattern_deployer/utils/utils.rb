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
  module Utils
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def join(*tokens)
        tokens.join("-")
      end
    end

    # instance methods
    def to_bool(obj)
      if obj.class == String
        "true".casecmp(obj) == 0
      else
        !!obj
      end
    end

  end
end