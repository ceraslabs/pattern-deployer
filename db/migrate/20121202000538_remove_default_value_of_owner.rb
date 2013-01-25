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
class RemoveDefaultValueOfOwner < ActiveRecord::Migration
  def up
    change_column_default :containers, :user_id, nil
    change_column_default :credentials, :user_id, nil
    change_column_default :nodes, :user_id, nil
    change_column_default :services, :user_id, nil
    change_column_default :supporting_services, :user_id, nil
    change_column_default :templates, :user_id, nil
    change_column_default :topologies, :user_id, nil
    change_column_default :uploaded_files, :user_id, nil
  end

  def down
    change_column_default :containers, :user_id, 3
    change_column_default :credentials, :user_id, 3
    change_column_default :nodes, :user_id, 3
    change_column_default :services, :user_id, 3
    change_column_default :supporting_services, :user_id, 3
    change_column_default :templates, :user_id, 3
    change_column_default :topologies, :user_id, 3
    change_column_default :uploaded_files, :user_id, 3
  end
end