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

class ContainersControllerTest < ActionController::TestCase

  include Devise::TestHelpers
  include RestfulHelper

  def setup
    @user = users(:user1)
    sign_in @user
    @test_topology_id = 1
    @test_container_id = 1
  end

  def teardown
    sign_out :user
  end

  test "create by name" do
    # test create a container
    assert_difference("Container.count") do
      post :create, :name => "test", :topology_id => @test_topology_id
      assert_response :success
    end
    assert_xml_equals get_response_element("container").to_s, '<container id="test" num_of_copies="1"/>'
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # test get the created container
    post :show, :topology_id => @test_topology_id, :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("container").to_s, '<container id="test" num_of_copies="1"/>'

    # test index the created container
    post :index, :topology_id => @test_topology_id, :node_id => @test_node_id
    assert_response(:success)
    assert_xml_equals get_response_element("//container[@id='test']").to_s, '<container id="test" num_of_copies="1"/>'

    # test destroy the container
    assert_difference("Container.count", -1) do
      post :destroy, :topology_id => @test_topology_id, :id => id
      assert_response :success
    end
  end
  
  test "create by xml" do
    # valid create
    xml = '<container id="xml" num_of_copies="2"><node id="node"/></container>'
    assert_difference("Container.count") do
	  assert_difference("Node.count") do
        post :create, :topology_id => @test_topology_id, :definition => xml
        assert_response :success
      end
    end
    assert_xml_equals get_response_element("container").to_s, xml
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    assert_difference("Container.count", -1) do
      assert_difference("Node.count", -1) do
        post :destroy, :topology_id => @test_topology_id, :id => id
        assert_response :success
      end
    end
  end

  test "xml validation" do
    # create container by invalid xml
    get_invalid_containers.each do |invalid_xml|
      assert_no_differences do
        post :create, :topology_id => @test_topology_id, :definition => invalid_xml
        assert_response :bad_request, "invalid xml passed the validation: #{invalid_xml}"
        assert_select "error_type", "XmlValidationError"
      end
    end

    # create container by valid xml
    get_valid_containers.each do |xml|
      post :create, :topology_id => @test_topology_id, :definition => xml
      assert_response :success, "valid xml didn't pass the validation.\nXML: #{xml}\nResponse: #{@response.body}"
      id = Rails.application.routes.recognize_path(get_self_link)[:id]

      post :destroy, :topology_id => @test_topology_id, :id => id
      assert_response :success
    end
  end

  test "rename operation" do
    xml = '<container id="rename" num_of_copies="1"/>'
    post :create, :topology_id => @test_topology_id, :definition => xml
    assert_response :success
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # rename the container to new_name
	xml = '<container id="new_name" num_of_copies="1"/>'
    post :update, :topology_id => @test_topology_id, :id => id, 
         :operation => "rename", :name => "new_name"
    assert_response(:success)
    assert_xml_equals get_response_element("container").to_s, xml

    # in ehe case the name is already taken
    post :update, :topology_id => @test_topology_id, :id => id,
         :operation => "rename", :name => "web_host_container"
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"
    get :show, :topology_id => @test_topology_id, :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("container").to_s, xml

    # rename with name parameter missing
    post :update, :topology_id => @test_topology_id, :id => id, :operation => "rename"
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"
    get :show, :topology_id => @test_topology_id, :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("container").to_s, xml
  end

  test "scale operation" do
    # TODO nodes_templates count
    xml = '<container id="xml" num_of_copies="1"/>'
    post :create, :topology_id => @test_topology_id, :definition => xml
    assert_response(:success)
    assert_xml_equals get_response_element("container").to_s, xml
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # scale up
    xml = '<container id="xml" num_of_copies="2"/>'
    post :update, :topology_id => @test_topology_id, :operation => "scale", :num_of_copies => "2", :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("container").to_s, xml

    # scale down
    xml = '<container id="xml" num_of_copies="1"/>'
    post :update, :topology_id => @test_topology_id, :operation => "scale", :num_of_copies => "1", :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("container").to_s, xml

    # scale with invalid num_of_copies
    post :update, :topology_id => @test_topology_id, :operation => "scale", :num_of_copies => "not_number", :id => id
    assert_response(:bad_request)
    post :show, :topology_id => @test_topology_id, :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("container").to_s, xml

    # scale with num_of_copies missing
    post :update, :topology_id => @test_topology_id, :operation => "scale", :id => id
    assert_response(:bad_request)
    post :show, :topology_id => @test_topology_id, :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("container").to_s, xml
  end

  test "unknown operation" do
    post :update, :topology_id => @test_topology_id, :id => @test_container_id, :operation => "unknown"
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"
  end

  test "no permission" do
    @user = users(:user2)
    sign_out :user
    sign_in @user

    # verify the response when permission denied
    post :show, :topology_id => @test_topology_id, :id => @test_container_id
    assert_response(:forbidden)
    assert_select "error_type", "AccessDeniedError"

    node = Node.find(@test_container_id)
    post :index, :topology_id => @test_topology_id
    assert_response(:success)
    assert_select "nodes node[id='#{node.node_id}']", false
  end
end