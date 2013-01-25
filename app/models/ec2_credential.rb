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
class Ec2Credential < Credential

  alias_attribute :access_key_id, :aws_access_key_id
  alias_attribute :secret_access_key, :aws_secret_access_key

  attr_accessible :aws_access_key_id, :aws_secret_access_key, :access_key_id, :secret_access_key

  validates :aws_access_key_id, :presence => true
  validates :aws_secret_access_key, :presence => true
end
