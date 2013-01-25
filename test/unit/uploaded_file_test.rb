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
require 'test_helper'

class UploadedFileTest < ActiveSupport::TestCase

  def setup
    @user = users(:user1)
    @test_file = "/tmp/test.sql"
    File.open(@test_file, "w") do |f|
      f.write("something")
    end
  end
  
  def teardown
    FileUtils.rm(@test_file) if File.exists?(@test_file)
  end

  test "uploaded file attribute validation" do
    # verify presence of attributes
    file = SqlScriptFile.create(:file_name => "name", :owner => @user)
    assert file.valid?, "Valid file is not saved #{file.errors.full_messages}"
    file.destroy

    # verify file is not saved with imcomplete attributes 
    file = SqlScriptFile.create
    assert_equal file.errors.size, 2, "Unexpected number of errors"
    assert file.errors[:owner].any?, "No error message when owner not present"
    assert file.errors[:file_name].any?, "No error message when file_name not present"

    # verify file name cannot be duplicated
    file = SqlScriptFile.create(:file_name => "sql", :owner => @user)
    assert_equal file.errors.size, 1, "Unexpected number of errors"
    assert file.errors[:file_name].any?, "No message on file_name"

    # test identity file
    file = IdentityFile.create(:file_name => "any", :owner => @user, :key_pair_id => "my_id", :for_cloud => "ec2")
    assert file.valid?, "valid file is not saved: #{file.errors.full_messages}"
    file.destroy

    # incomplete parameters list
    file = IdentityFile.create(:file_name => "any", :owner => @user)
    assert_equal file.errors.size, 2, "Unexpected number of errors"
    assert file.errors[:key_pair_id].any?, "No message on key_pair_id"
    assert file.errors[:for_cloud].any?, "No message on for_cloud"

    # cloud is not supported
    file = IdentityFile.create(:file_name => "any", :owner => @user, :key_pair_id => "my_id", :for_cloud => "not_supported_cloud")
    assert_equal file.errors.size, 1, "Unexpected number of errors: #{file.errors.full_messages}"
    assert file.errors[:for_cloud].any?, "Error is not on the right attribute"

    # key_pair_id is duplicated
    file = IdentityFile.create(:file_name => "any", :owner => @user, :key_pair_id => "keypair", :for_cloud => "ec2")
    assert_equal file.errors.size, 1, "Unexpected number of errors: #{file.errors.full_messages}"
    assert file.errors[:key_pair_id].any?, "Error is not on the right attribute"

    # test war file
    file = WarFile.create(:file_name => "any.war", :owner => @user)
    assert file.valid?, "valid file is not saved: #{file.errors.full_messages}"
    file.destroy

    file = WarFile.create(:file_name => "any", :owner => @user)
    assert_equal file.errors.size, 1, "Unexpected number of errors"
    assert file.errors[:file_name].any?, "No message on file_name"
  end

  test "file upload" do
    # verify file upload is working
    file = SqlScriptFile.new(:file_name => "name", :owner => @user)
    File.open(@test_file, "r") do |file_io|
      file.upload(file_io)
    end
    assert file.save, "Valid file is not uploaded: #{file.errors.full_messages}"
    assert File.exists?(file.get_file_path)
    File.open(file.get_file_path, "r") do |f|
      assert_equal f.read, "something"
    end

    # test reupload
    File.open(@test_file, "w") do |f|
      f.write "another thing"
    end
    File.open(@test_file, "r") do |file_io|
      file.reupload(file_io)
    end
    assert file.valid?, "Valid file is not uploaded: #{file.errors.full_messages}"
    File.open(file.get_file_path, "r") do |f|
      assert_equal f.read, "another thing"
    end

    # test file destroy
    file.destroy
    assert !File.exists?(file.get_file_path)

    # verify file is not uploaded if invalid
    file = SqlScriptFile.new(:file_name => "name")
    File.open(@test_file, "r") do |file_io|
      file.upload(file_io)
    end
    assert !file.save, "Not valid file is saved"
    assert !File.exists?(file.get_file_path)
  end

  test "file rename" do
    file = WarFile.new(:file_name => "somename.war", :owner => @user)
    File.open(@test_file, "r") do |file_io|
      file.upload(file_io)
    end
    assert file.save, "Valid file is not uploaded: #{file.errors.full_messages}"
    old_file = file.get_file_path
    assert File.exists?(old_file)

    # verify rename is working
    file.rename("new_name.war")
    assert file.valid?, "Renamed file is not saved #{file.errors.full_messages}"
    assert File.exists?(file.get_file_path)
    assert !File.exists?(old_file)

    # if the new name is invalid, verify rollback is working
    old_file = file.get_file_path
    assert_raise(ActiveRecord::RecordInvalid) do
      file.rename("not_valid_name")
    end
    assert !File.exists?(file.get_file_path)
    assert File.exists?(old_file)

    file.destroy
  end

  test "permission" do
    file = uploaded_files(:war)

    # resource owner has all permission
    user = users(:user1)
    ability = Ability.new(user)
    assert ability.can?(:show, file)
    assert ability.can?(:create, file)
    assert ability.can?(:destroy, file)
    assert ability.can?(:update, file)

    # normal user other than owner don't have permission
    user = users(:user2)
    ability = Ability.new(user)
    assert ability.cannot?(:show, file)
    assert ability.cannot?(:create, file)
    assert ability.cannot?(:destroy, file)
    assert ability.cannot?(:update, file)

    # admin has all permission regardless resource owner
    user = users(:admin)
    ability = Ability.new(user)
    assert ability.can?(:show, file)
    assert ability.can?(:create, file)
    assert ability.can?(:destroy, file)
    assert ability.can?(:update, file)
  end
end