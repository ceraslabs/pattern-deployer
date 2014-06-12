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
require "pattern_deployer"

class Credential < ActiveRecord::Base
  include PatternDeployer::Deployer::State

  belongs_to :owner, :autosave => true, :class_name => "User", :foreign_key => "user_id", :inverse_of => :credentials
  has_and_belongs_to_many :topologies

  attr_accessible :credential_id, :for_cloud, :owner, :id

  validate :credential_id_unique
  validates :for_cloud, :inclusion => { :in => Rails.configuration.supported_clouds, :message => "cloud %{value} is not supported" }
  validates_presence_of :owner

  before_save :credential_mutable
  before_destroy :credential_mutable


  def credential_id_unique
    query = "credential_id = :credential_id AND user_id = :user_id"
    query_params = {:credential_id => self.credential_id, :user_id => owner.id}
    if self.id
      query += " AND id <> :id"
      query_params[:id] = self.id
    end

    if Credential.where(query, query_params).first
      errors.add(:credential_id, "'#{credential_id}' have already been taken")
    end
  end

  def unlock(&block)
    begin
      self.class.skip_callback(:save, :before, :credential_mutable)
      yield
    ensure
      self.class.set_callback(:save, :before, :credential_mutable)
    end
  end


  protected

  def credential_mutable
    if self.topologies.any? { |t| t.state != UNDEPLOY }
      msg = "Credential #{credential_id} cannot be modified. Please make sure it is not being used by any topology."
      fail InvalidOperationError, msg
    end
  end

end
