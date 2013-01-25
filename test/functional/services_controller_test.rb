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

class ServicesControllerTest < ActionController::TestCase

  include Devise::TestHelpers
  include RestfulHelper

  def setup
    @user = users(:user1)
    sign_in @user
    @test_topology_id = 1
    @test_node_id = 2
    @test_service_id = 2
  end

  def teardown
    sign_out @user if @user
  end

  test "create by name" do
    # test create an service
    assert_difference("Service.count") do
      post :create, :name => "openvpn_server", :topology_id => @test_topology_id, :node_id => @test_node_id
      assert_response :success
    end
    assert_xml_equals get_response_element("service").to_s, '<service name="openvpn_server"/>'
    new_service_id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # test get the created service
    post :show, :topology_id => @test_topology_id, :node_id => @test_node_id, :id => new_service_id
    assert_response(:success)
    assert_xml_equals get_response_element("service").to_s, '<service name="openvpn_server"/>'

    # test index the created service
    post :index, :topology_id => @test_topology_id, :node_id => @test_node_id
    assert_response(:success)
    assert_xml_equals get_response_element("//service[@name='openvpn_server']").to_s, '<service name="openvpn_server"/>'

    # test destroy the service
    assert_difference("Service.count", -1) do
      post :destroy, :topology_id => @test_topology_id, :node_id => @test_node_id, :id => new_service_id
      assert_response :success
    end

    # invalid create service by name
    assert_no_difference("Service.count") do
      post :create, :name => "invalid_service", :topology_id => @test_topology_id, :node_id => @test_node_id
      assert_response :bad_request
    end
    assert_select "error_type", "ParametersValidationError"
  end
  
  test "create by xml" do
    # valid create
    xml = '<service name="web_server"><database node="data_host"/></service>'
    assert_difference("Service.count") do
      assert_difference("ServiceToNodeRef.count") do
        post :create, :topology_id => @test_topology_id, :node_id => @test_node_id, :definition => xml
        assert_response :success
      end
    end
    assert_xml_equals get_response_element("service").to_s, xml
    new_service_id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # test get the created service
    post :show, :topology_id => @test_topology_id, :node_id => @test_node_id, :id => new_service_id
    assert_response(:success)
    assert_xml_equals get_response_element("service").to_s, xml

    assert_difference("Service.count", -1) do
      assert_difference("ServiceToNodeRef.count", -1) do
        post :destroy, :topology_id => @test_topology_id, :node_id => @test_node_id, :id => new_service_id
        assert_response :success
      end
    end
  end

  test "xml validation" do
    # create service by invalid xml
    get_invalid_services.each do |invalid_xml|
      assert_no_differences do
        post :create, :topology_id => @test_topology_id, :node_id => @test_node_id, :definition => invalid_xml
        assert_response :bad_request
        assert_select "error_type", "XmlValidationError"
      end
    end

    # create service by valid xml
    get_valid_services.each do |xml|
      post :create, :topology_id => @test_topology_id, :node_id => @test_node_id, :definition => xml
      assert_response :success
    end
  end

  test "rename operation" do
    old_name = services(:tomcat).service_id

    # rename the service to web_server
    post :update, :topology_id => @test_topology_id, :node_id => @test_node_id, :id => @test_service_id, 
         :operation => "rename", :name => "web_server"
    assert_response(:success)
    assert_equal get_response_element("service")["name"], "web_server"

    # rename the service to an invalid name
    post :update, :topology_id => @test_topology_id, :node_id => @test_node_id, :id => @test_service_id, 
         :operation => "rename", :name => "invalid_name"
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"
    get :show, :topology_id => @test_topology_id, :node_id => @test_node_id, :id => @test_service_id
    assert_response(:success)
    assert_equal get_response_element("service")["name"], "web_server"

    # rename the service without providing name parameter
    post :update, :topology_id => @test_topology_id, :node_id => @test_node_id, :id => @test_service_id, 
         :operation => "rename"
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"
    get :show, :topology_id => @test_topology_id, :node_id => @test_node_id, :id => @test_service_id
    assert_response(:success)
    assert_equal get_response_element("service")["name"], "web_server"

    # rename it back
    post :update, :topology_id => @test_topology_id, :node_id => @test_node_id, :id => @test_service_id, 
         :operation => "rename", :name => old_name
    assert_response(:success)
  end

  test "redefine operation" do
    get :show, :topology_id => @test_topology_id, :node_id => @test_node_id, :id => @test_service_id
    assert_response(:success)
    old_xml = get_response_element("service").to_s

    # redef the service
    xml = '<service name="web_server"><database node="data_host"/></service>'
    post :update, :topology_id => @test_topology_id, :node_id => @test_node_id, :id => @test_service_id, 
         :operation => "redefine", :definition => xml
    assert_response(:success)
    assert_xml_equals get_response_element("service").to_s, xml

    # redef rollback if definition is invalid
    invalid_xml = '<service name="openvpn_client"><openvpn_server node="inavlid_node"/></service>'
    post :update, :topology_id => @test_topology_id, :node_id => @test_node_id, :id => @test_service_id, 
         :operation => "redefine", :definition => invalid_xml
    assert_response(:bad_request)
    assert_select "error_type", "XmlValidationError"
    get :show, :topology_id => @test_topology_id, :node_id => @test_node_id, :id => @test_service_id
    assert_response(:success)
    assert_xml_equals get_response_element("service").to_s, xml

    # redef without providing definition parameter
    post :update, :topology_id => @test_topology_id, :node_id => @test_node_id, :id => @test_service_id, 
         :operation => "redefine"
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"
    get :show, :topology_id => @test_topology_id, :node_id => @test_node_id, :id => @test_service_id
    assert_response(:success)
    assert_xml_equals get_response_element("service").to_s, xml

    # redef it back
    post :update, :topology_id => @test_topology_id, :node_id => @test_node_id, :id => @test_service_id, 
         :operation => "redefine", :definition => old_xml
    assert_response(:success)
  end

  test "unknown operation" do
    post :update, :topology_id => @test_topology_id, :node_id => @test_node_id, :id => @test_service_id, :operation => "unknown"
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"
  end

  test "no permission" do
    @user = users(:user2)
    sign_out :user
    sign_in @user
	
    # verify the response when permission denied
    post :show, :topology_id => @test_topology_id, :node_id => @test_node_id, :id => @test_service_id
    assert_response(:forbidden)
    assert_select "error_type", "AccessDeniedError"

    service = Service.find(@test_service_id)
    post :index, :topology_id => @test_topology_id, :node_id => @test_node_id
    assert_response(:success)
    assert_select "services service[name='#{service.service_id}']", false
  end
end