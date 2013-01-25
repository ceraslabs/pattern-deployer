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
class CreateNodesServicesTable < ActiveRecord::Migration
  def up
    create_table :nodes_services, :id => false do |t|
      t.references :node
      t.references :service
    end
    add_index :nodes_services, [:node_id, :service_id]
    add_index :nodes_services, [:service_id, :node_id]
  end

  def down
  end
end