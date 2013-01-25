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
class CreateUploadFileTable < ActiveRecord::Migration
  def up
    create_table :uploaded_files do |t|
      t.string :type
      t.string :war_file_id
      t.string :script_id
      t.string :identify_file_id
      t.string :key_pair_id
      t.string :for_cloud

      t.timestamps
    end
  end

  def down
    drop_table :uploaded_files
  end
end