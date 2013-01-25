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

class CredentialsControllerTest < ActionController::TestCase

  include Devise::TestHelpers
  include RestfulHelper

  def setup
    @user = users(:user1)
    sign_in @user
  end

  def teardown
    sign_out :user
  end

  test "create ec2 credential" do
    # test create a credential
    xml = '<credential>
      <credential_id>test</credential_id>
      <for_cloud>ec2</for_cloud>
      <aws_access_key_id>somekey</aws_access_key_id>
    </credential>'
    assert_difference("Ec2Credential.count") do
      post :create, :name => "test", :for_cloud => "ec2", :access_key_id => "somekey", :secret_access_key => "secretkey"
      assert_response :success, @response.body
    end
    assert_xml_equals get_response_element("credential").to_s, xml
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # test get the created credential
    post :show, :topology_id => @test_topology_id, :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("credential").to_s, xml

    # test destroy the credential
    assert_difference("Ec2Credential.count", -1) do
      post :destroy, :id => id
      assert_response :success
    end
  end

  test "create openstack credential" do 
    # test create a credential
    xml = '<credential>
      <credential_id>test</credential_id>
      <for_cloud>openstack</for_cloud>
      <openstack_username>user</openstack_username>
      <openstack_tenant>tenant</openstack_tenant>
      <openstack_endpoint>endpoint</openstack_endpoint>
    </credential>'
    assert_difference("OpenstackCredential.count") do
      post :create, :name => "test", :for_cloud => "openstack", :username => "user", :password => "pwd", :tenant => "tenant", :endpoint => "endpoint"
      assert_response :success, @response.body
    end
    assert_xml_equals get_response_element("credential").to_s, xml
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # test get the created credential
    post :show, :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("credential").to_s, xml

    # test index
    post :index
    assert_response(:success)
    assert_have_values get_response_elements("//credential_id"), ["test"]

    # test destroy the credential
    assert_difference("OpenstackCredential.count", -1) do
      post :destroy, :id => id
      assert_response :success
    end

    post :index
    assert_response(:success)
    assert_not_have_values get_response_elements("credential_id"), ["test"]
  end
  
  test "test invalid parameter" do
    # for_cloud is missing
    assert_no_difference("Ec2Credential.count") do
      post :create, :name => "test", :access_key_id => "somekey", :secret_access_key => "secretkey"
      assert_response :bad_request
      assert_select "error_type", "ParametersValidationError"
    end

    # the cloud is not supported
    assert_no_difference("Ec2Credential.count") do
      assert_no_difference("OpenstackCredential.count") do
        post :create, :name => "unsupported", :access_key_id => "somekey", :secret_access_key => "secretkey"
        assert_response :bad_request
        assert_select "error_type", "ParametersValidationError"
      end
    end

    # credential id must be unique
    assert_no_difference("Ec2Credential.count") do
      post :create, :name => "ec2", :access_key_id => "somekey", :secret_access_key => "secretkey"
      assert_response :bad_request
      assert_select "error_type", "ParametersValidationError"
    end
  end

  test "rename operation" do
    post :create, :name => "rename", :for_cloud => "ec2", :access_key_id => "somekey", :secret_access_key => "secretkey"
    assert_response :success, @response.body
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # rename the credential to new_name
    post :update, :id => id, :operation => "rename", :name => "new_name"
    assert_response :success, @response.body
    assert_select "credential_id", "new_name"

    # in the case the name is already taken
    post :update, :id => id, :operation => "rename", :name => "ec2"
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"

    # rename with name parameter missing
    post :update, :id => id, :operation => "rename"
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"
  end

  test "redefine" do
    xml = '<credential>
      <credential_id>ec2</credential_id>
      <for_cloud>ec2</for_cloud>
      <aws_access_key_id>newkey</aws_access_key_id>
    </credential>'
    post :update, :id => credentials(:ec2).id, :operation => "redefine", :access_key_id => "newkey", :secret_access_key => "newsecret"
    assert_response :success, @response.body
    assert_xml_equals get_response_element("credential").to_s, xml

    xml = '<credential>
      <credential_id>openstack</credential_id>
      <for_cloud>openstack</for_cloud>
      <openstack_username>newuser</openstack_username>
      <openstack_tenant>newtenant</openstack_tenant>
      <openstack_endpoint>newendpoint</openstack_endpoint>
    </credential>'
    # redefine the credential to new_name
    post :update, :id => credentials(:openstack).id, :operation => "redefine", :username => "newuser", :tenant => "newtenant", :endpoint => "newendpoint"
    assert_response(:success)
    assert_xml_equals get_response_element("credential").to_s, xml
  end

  test "unknown operation" do
    post :update, :id => credentials(:ec2).id, :operation => "unknown"
    assert_response :bad_request, @response.body
    assert_select "error_type", "ParametersValidationError"
  end

  test "no permission" do
    @user = users(:user2)
    sign_out :user
    sign_in @user

    # verify the response when permission denied
    post :show, :id => credentials(:ec2).id
    assert_response(:forbidden)
    assert_select "error_type", "AccessDeniedError"

    credential = Credential.find(credentials(:ec2).id)
    post :index
    assert_response(:success)
    assert_not_have_values get_response_elements("//credential_id"), [credential.credential_id]
  end
end