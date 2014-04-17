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

class Token < ActiveRecord::Base
  include PatternDeployer::Errors

  belongs_to :topology, :inverse_of => :tokens
  belongs_to :user

  attr_accessible :token, :topology, :user, :id
  validate :ensure_token_uniqueness, on: :create

  def self.generate(topology, user)
    loop do
      token = SecureRandom.urlsafe_base64(nil, false)
      transaction do
        unless exists?(token: token)
          record = create(token: token, topology: topology, user: user)
          return record
        end
      end
    end
  end

  def self.find_first(*args)
    where(*args).first
  end

  def topology?(topology_id)
    if topology_id.present?
      topology.id.to_s == topology_id.to_s
    else
      false
    end
  end

  protected

  def ensure_token_uniqueness
    self.class.find_each do |record|
      next if record.id == id

      if record.token == token
        errors.add(:token, "'#{token}' already exists.")
      elsif record.topology == topology && record.user == user
        errors.add(:topology, "'#{topology.topology_id}' have already been shared by you (#{user.email}).")
      else
        # No action required.
      end
    end
  end

end