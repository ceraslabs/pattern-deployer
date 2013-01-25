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
class OpenstackCredential < Credential

  alias_attribute :username, :openstack_username
  alias_attribute :password, :openstack_password
  alias_attribute :tenant, :openstack_tenant
  alias_attribute :endpoint, :openstack_endpoint

  attr_accessible :openstack_username, :openstack_password, :openstack_tenant, :openstack_endpoint
  attr_accessible :username, :password, :tenant, :endpoint

  validates :openstack_username, :presence => true
  validates :openstack_password, :presence => true
  validates :openstack_tenant, :presence => true
  validates :openstack_endpoint, :presence => true
end