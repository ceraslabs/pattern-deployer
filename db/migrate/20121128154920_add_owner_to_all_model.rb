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
class AddOwnerToAllModel < ActiveRecord::Migration
  def up
    # ALERT default value needs to be adjusted 
    add_column :containers, :user_id, :integer, :default => 3, :null => false
    add_column :credentials, :user_id, :integer, :default => 3, :null => false
    add_column :nodes, :user_id, :integer, :default => 3, :null => false
    add_column :services, :user_id, :integer, :default => 3, :null => false
    add_column :supporting_services, :user_id, :integer, :default => 3, :null => false
    add_column :templates, :user_id, :integer, :default => 3, :null => false
    add_column :topologies, :user_id, :integer, :default => 3, :null => false
    add_column :uploaded_files, :user_id, :integer, :default => 3, :null => false
  end

  def down
    remove_column :containers, :user_id
    remove_column :credentials, :user_id
    remove_column :nodes, :user_id
    remove_column :services, :user_id
    remove_column :supporting_services, :user_id
    remove_column :templates, :user_id
    remove_column :topologies, :user_id
    remove_column :uploaded_files, :user_id
  end
end