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
class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :token_authenticatable, :recoverable,
  # :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable, 
         :rememberable, :trackable, :validatable
  include PatternDeployer::Errors

  # Setup accessible (or protected) attributes for your model
  attr_accessible :email, :password, :password_confirmation, :remember_me, :role

  has_many :containers, :dependent => :destroy, :inverse_of => :owner
  has_many :credentials, :dependent => :destroy, :inverse_of => :owner
  has_many :nodes, :dependent => :destroy, :inverse_of => :owner
  has_many :services, :dependent => :destroy, :inverse_of => :owner
  has_many :templates, :dependent => :destroy, :inverse_of => :owner
  has_many :topologies, :dependent => :destroy, :inverse_of => :owner
  has_many :uploaded_files, :dependent => :destroy, :inverse_of => :owner

  validates :role, :inclusion => { :in => %w(user admin), :message => "%{value} is not a valid role" }

  delegate :can?, :cannot?, :to => :ability

  before_save :default_values

  def default_values
    if User.count == 0
      self.role = "admin"
    end
  end

  def admin?
    self.role == "admin"
  end

  def share(topology)
    fail AccessDeniedError if cannot?(:update, topology)
    token = Token.generate(topology, self)
    if token.valid?
      true
    else
      return false, token.errors.full_messages.join(";")
    end
  end

  def share!(topology)
    success, msg = share(topology)
    fail InvalidOperationError, msg unless success
  end

  def unshare(topology)
    fail AccessDeniedError if cannot?(:update, topology)
    record = Token.find_first(topology: topology, user: self)
    if record
      record.destroy
      true
    else
      false
    end
  end

  def unshare!(topology)
    unless unshare(topology)
      msg = "Topology '#{topology.topology_id}' was not shared by you (#{email}) before."
      fail InvalidOperationError, msg
    end
  end

  def has_shared?(topology)
    Token.find_first(topology: topology, user: self).present?
  end

  protected

  def ability
    @ability ||= Ability.new(self)
  end

end