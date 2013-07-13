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
class IdentityFile < UploadedFile

  attr_accessible :key_pair_id, :for_cloud

  validates :for_cloud, :inclusion => { :in => Rails.configuration.supported_clouds, :message => "cloud %{value} is not supported" }
  validates :key_pair_id, :presence => true
  validate :key_pair_id_unique


  protected

  def key_pair_id_unique
    self.class.all.each do |file|
      if file.id != self.id && file.key_pair_id == self.key_pair_id && file.owner.id == self.owner.id
        errors.add(:key_pair_id, "'#{self.key_pair_id}' have already been uploaded")
      end
    end
  end
end