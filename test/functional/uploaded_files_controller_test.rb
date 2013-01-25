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

class UploadedFilesControllerTest < ActionController::TestCase

  include Devise::TestHelpers
  include RestfulHelper

  def setup
    @user = users(:user1)
    sign_in @user
  end

  def teardown
    sign_out :user
  end

  test "upload" do
    # upload create sql script file
    file = fixture_file_upload("files/test.sql", "text/plain")
    assert_difference("SqlScriptFile.count") do
      post :create, :file => file, :file_type => "sql_script_file"
      assert_response :success, @response.body
    end
    original_content, uploaded_content = nil, nil
    File.open(file.path, "r") do |input|
      original_content = input.read
    end
    uploaded_file = UploadedFile.find_by_file_name("test.sql")
    assert_not_nil uploaded_file
    File.open(uploaded_file.get_file_path, "r") do |input|
      uploaded_content = input.read
    end
    assert_equal original_content, uploaded_content

    id = Rails.application.routes.recognize_path(get_self_link)[:id]
    xml = '<uploaded_file>
      <file_type>sql_script_file</file_type>
      <file_name>test.sql</file_name>
    </uploaded_file>'
    post :show, :id => id
    assert_response :success
    assert_xml_equals get_response_element("uploaded_file").to_s, xml

    # test cretae identity file
    file = fixture_file_upload("files/test.pem", "text/plain")
    assert_difference("IdentityFile.count") do
      post :create, :file => file, :file_type => "identity_file", :for_cloud => "ec2", :key_pair_id => "test"
      assert_response :success, @response.body
    end
    File.open(file.path, "r") do |input|
      original_content = input.read
    end
    uploaded_file = UploadedFile.find_by_file_name("test.pem")
    assert_not_nil uploaded_file
    File.open(uploaded_file.get_file_path, "r") do |input|
      uploaded_content = input.read
    end
    assert_equal original_content, uploaded_content

    id = Rails.application.routes.recognize_path(get_self_link)[:id]
    xml = '<uploaded_file>
      <file_type>identity_file</file_type>
      <file_name>test.pem</file_name>
      <key_pair_id>test</key_pair_id>
      <for_cloud>ec2</for_cloud>
    </uploaded_file>'
    post :show, :id => id
    assert_response :success
    assert_xml_equals get_response_element("uploaded_file").to_s, xml

    # test uploaded war file
    file = fixture_file_upload("files/test.war", "application/x-zip")
    assert_difference("WarFile.count") do
      post :create, :file => file, :file_type => "war_file"
      assert_response :success
    end
    File.open(file.path, "r") do |input|
      original_content = input.read
    end
    uploaded_file = UploadedFile.find_by_file_name("test.war")
    assert_not_nil uploaded_file
    File.open(uploaded_file.get_file_path, "r") do |input|
      uploaded_content = input.read
    end
    assert_equal original_content, uploaded_content

    id = Rails.application.routes.recognize_path(get_self_link)[:id]
    xml = '<uploaded_file>
      <file_type>war_file</file_type>
      <file_name>test.war</file_name>
    </uploaded_file>'
    post :show, :id => id
    assert_response :success
    assert_xml_equals get_response_element("uploaded_file").to_s, xml

    # test uploaded war with name different from original file name
    file = fixture_file_upload("files/test.war", "application/x-zip")
    assert_difference("WarFile.count") do
      post :create, :file => file, :file_type => "war_file", :file_name => "test2.war"
      assert_response :success, @response.body
    end
    File.open(file.path, "r") do |input|
      original_content = input.read
    end
    uploaded_file = UploadedFile.find_by_file_name("test2.war")
    assert_not_nil uploaded_file
    File.open(uploaded_file.get_file_path, "r") do |input|
      uploaded_content = input.read
    end
    assert_equal original_content, uploaded_content

    id = Rails.application.routes.recognize_path(get_self_link)[:id]
    xml = '<uploaded_file>
      <file_type>war_file</file_type>
      <file_name>test2.war</file_name>
    </uploaded_file>'
    post :show, :id => id
    assert_response :success
    assert_xml_equals get_response_element("uploaded_file").to_s, xml

    # test index
    post :index
    assert_response :success
    file_names = get_response_elements("//file_name")
    assert_have_values file_names, ["test.sql", "test.pem", "test.war", "test2.war"]

    # test destroy
    assert_difference("WarFile.count", -1) do
      post :destroy, :id => id
      assert_response :success
    end
    file_names = get_response_elements("//file_name")
    assert_have_values file_names, ["test.sql", "test.pem", "test.war"]
    assert_not_have_values file_names, ["test2.war"]
  end

  test "test invalid parameter" do
    # parameter file is missing
    assert_no_difference("SqlScriptFile.count") do
      post :create, :file_type => "sql_script_file"
      assert_response :bad_request, @response.body
      assert_select "error_type", "ParametersValidationError"
    end

    # parameter file_type is missing
    file = fixture_file_upload("files/test.sql", "text/plain")
    assert_no_difference("SqlScriptFile.count") do
      post :create, :file => file
      assert_response :bad_request
      assert_select "error_type", "ParametersValidationError"
    end

    # parameter file_type is missing
    file = fixture_file_upload("files/test.sql", "text/plain")
    assert_no_difference("SqlScriptFile.count") do
      post :create, :file => file
      assert_response :bad_request
      assert_select "error_type", "ParametersValidationError"
    end

    # parameter for_cloud is missing
    file = fixture_file_upload("files/test.pem", "text/plain")
    assert_no_difference("IdentityFile.count") do
      post :create, :file => file, :file_type => "identity_file", :key_pair_id => "test"
      assert_response :bad_request
      assert_select "error_type", "ParametersValidationError"
    end

    # The specified cloud is not supported
    file = fixture_file_upload("files/test.pem", "text/plain")
    assert_no_difference("IdentityFile.count") do
      post :create, :file => file, :file_type => "identity_file", :key_pair_id => "test", :for_cloud => "not_supported"
      assert_response :bad_request
      assert_select "error_type", "ParametersValidationError"
    end

    # The specified cloud is not supported
    file = fixture_file_upload("files/test.pem", "text/plain")
    assert_no_difference("IdentityFile.count") do
      post :create, :file => file, :file_type => "identity_file", :key_pair_id => "test", :for_cloud => "not_supported"
      assert_response :bad_request
      assert_select "error_type", "ParametersValidationError"
    end

    # Parameter key_pair_id is missing
    file = fixture_file_upload("files/test.pem", "text/plain")
    assert_no_difference("IdentityFile.count") do
      post :create, :file => file, :file_type => "identity_file", :for_cloud => "ec2"
      assert_response :bad_request
      assert_select "error_type", "ParametersValidationError"
    end

    # file name must be unique within the same type
    file = fixture_file_upload("files/test.sql", "text/plain")
    assert_no_difference("IdentityFile.count") do
      post :create, :file => file, :file_name => "sql", :file_type => "sql_script_file"
      assert_response :bad_request
      assert_select "error_type", "ParametersValidationError"
    end
  end
 
  test "rename operation" do
    # upload create sql script file
    file_name = "test.sql"
    file = fixture_file_upload("files/#{file_name}", "text/plain")
    assert_difference("SqlScriptFile.count") do
      post :create, :file => file, :file_type => "sql_script_file"
      assert_response :success, @response.body
      assert_select "file_name", file_name
    end
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # rename the credential to new_name
    old_file_name = file_name
    file_name = "new_name.sql"
    post :update, :id => id, :operation => "rename", :file_name => file_name
    assert_response :success, @response.body
    assert_select "file_name", file_name
    uploaded_file = UploadedFile.find_by_file_name(old_file_name)
    assert_nil uploaded_file
    uploaded_file = UploadedFile.find_by_file_name(file_name)
    assert_not_nil uploaded_file
    assert File.exists?(uploaded_file.get_file_path)

    # in the case the name is already taken
    old_file_name = file_name
    file_name = "sql"
    post :update, :id => id, :operation => "rename", :file_name => file_name
    assert_response :bad_request, @response.body
    assert_select "error_type", "ParametersValidationError"
    uploaded_file = UploadedFile.find_by_file_name(old_file_name)
    assert_not_nil uploaded_file
    assert File.exists?(uploaded_file.get_file_path)

    # rename with name parameter missing
    post :update, :id => id, :operation => "rename"
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"
    uploaded_file = UploadedFile.find_by_file_name(old_file_name)
    assert_not_nil uploaded_file
    assert File.exists?(uploaded_file.get_file_path)
  end

  test "reupload" do
    # upload create sql script file
    file = fixture_file_upload("files/test.sql", "text/plain")
    assert_difference("SqlScriptFile.count") do
      post :create, :file => file, :file_type => "sql_script_file"
      assert_response :success, @response.body
    end
    original_content, uploaded_content = nil, nil
    File.open(file.path, "r") do |input|
      original_content = input.read
    end
    uploaded_file = UploadedFile.find_by_file_name("test.sql")
    assert_not_nil uploaded_file
    File.open(uploaded_file.get_file_path, "r") do |input|
      uploaded_content = input.read
    end
    assert_equal original_content, uploaded_content
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # reupload create sql script file
    file = fixture_file_upload("files/test", "text/plain")
    post :update, :file => file, :id => id, :operation => "reupload"
    assert_response :success, @response.body
    File.open(file.path, "r") do |input|
      original_content = input.read
    end
    uploaded_file = UploadedFile.find_by_file_name("test.sql")
    assert_not_nil uploaded_file
    File.open(uploaded_file.get_file_path, "r") do |input|
      uploaded_content = input.read
    end
    assert_equal original_content, uploaded_content
  end

  test "unknown operation" do
    post :update, :id => uploaded_files(:sql).id, :operation => "unknown"
    assert_response :bad_request, @response.body
    assert_select "error_type", "ParametersValidationError"
  end

  test "no permission" do
    @user = users(:user2)
    sign_out :user
    sign_in @user

    # verify the response when permission denied
    post :show, :id => uploaded_files(:sql).id
    assert_response(:forbidden)
    assert_select "error_type", "AccessDeniedError"

    file = UploadedFile.find(uploaded_files(:sql).id)
    post :index
    assert_response(:success)
    assert_not_have_values get_response_elements("//file_name"), [file.file_name]
  end
end