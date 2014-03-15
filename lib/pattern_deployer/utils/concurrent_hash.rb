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
    class ConcurrentHash
      def initialize
        @reader, @writer = {}, {}
        @lock = Mutex.new
      end

      def [](key)
        @reader[key]
      end

      def []=(key, value)
        @lock.synchronize do
          @writer[key] = value
          @reader, @writer = @writer, @reader
          @writer[key] = value
        end
      end

      def delete(key)
        @lock.synchronize do
          @writer.delete(key)
          @reader, @writer = @writer, @reader
          @writer.delete(key)
        end
      end

      def each(&block)
        @lock.synchronize do
          @reader.each(&block)
        end
      end

    end
  end
end