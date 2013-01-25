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

class NodesControllerTest < ActionController::TestCase

  include Devise::TestHelpers
  include RestfulHelper

  def setup
    @user = users(:user1)
    sign_in @user
    @test_topology_id = 1
    @test_container_id = 1
    @test_node_id = 2
  end

  def teardown
    sign_out :user
  end

  test "create by name" do
    # test create an node from container
    assert_difference("Node.count") do
      post :create, :name => "test2", :topology_id => @test_topology_id, :container_id => @test_container_id
      assert_response :success
    end
    assert_xml_equals get_response_element("node").to_s, '<node id="test2"/>'

    # test create an node from topology
    assert_difference("Node.count") do
      post :create, :name => "test", :topology_id => @test_topology_id
      assert_response :success
    end
    assert_xml_equals get_response_element("node").to_s, '<node id="test"/>'
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # test get the created node
    post :show, :topology_id => @test_topology_id, :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("node").to_s, '<node id="test"/>'

    # test index the created node
    post :index, :topology_id => @test_topology_id, :node_id => @test_node_id
    assert_response(:success)
    assert_xml_equals get_response_element("//node[@id='test']").to_s, '<node id="test"/>'

    # test destroy the node
    assert_difference("Node.count", -1) do
      post :destroy, :topology_id => @test_topology_id, :id => id
      assert_response :success
    end
  end

  test "create by xml" do
    # valid create
    db_xml = '<node id="test_database"><use_template name="ec2_small_instance"/><service name="database_server"/></node>'
    assert_difference("Node.count") do
	  assert_difference("Service.count") do
        assert_difference("get_nodes_templates_count") do
          post :create, :topology_id => @test_topology_id, :definition => db_xml
          assert_response :success
        end
      end
    end
    assert_xml_equals get_response_element("node").to_s, db_xml
    db_id = Rails.application.routes.recognize_path(get_self_link)[:id]

    web_xml = '<node id="test_web_server">
      <service name="web_server">
        <database node="test_database"/>
      </service>
      <for_cloud>EC2</for_cloud>
      <ssh_user>ubuntu</ssh_user>
    </node>'
    assert_difference("Node.count") do
      assert_difference("ServiceToNodeRef.count") do
        post :create, :topology_id => @test_topology_id, :definition => web_xml
        assert_response :success
      end
    end
    assert_xml_equals get_response_element("node").to_s, web_xml
    web_id = Rails.application.routes.recognize_path(get_self_link)[:id]

    assert_difference("Node.count", -1) do
      assert_difference("Service.count", -1) do
        assert_difference("get_nodes_templates_count", -1) do
          post :destroy, :topology_id => @test_topology_id, :id => db_id
          assert_response :success
        end
      end
    end
    web_xml = '<node id="test_web_server">
      <service name="web_server"/>
      <for_cloud>EC2</for_cloud>
      <ssh_user>ubuntu</ssh_user>
    </node>'
    post :show, :topology_id => @test_topology_id, :id => web_id
    assert_xml_equals get_response_element("node").to_s, web_xml

    assert_difference("Node.count", -1) do
      post :destroy, :topology_id => @test_topology_id, :id => web_id
      assert_response :success
    end
  end

  test "node nest within another node" do
    # valid create
    outer_xml = '<node id="outer_data_host">
          <use_template name="ec2_small_instance"/>
          <use_template name="database_container"/>
        </node>'
    assert_difference("Node.count") do
      assert_difference("get_nodes_templates_count", 2) do
        post :create, :topology_id => @test_topology_id, :definition => outer_xml
        assert_response :success
      end
    end
    assert_xml_equals get_response_element("node").to_s, outer_xml
    outer_id = Rails.application.routes.recognize_path(get_self_link)[:id]

    inner_xml = '<node id="inner_data_host">
          <use_template name="nested_instance"/>
          <service name="database_server"/>
          <nest_within node="outer_data_host"/>
        </node>'
    assert_difference("Node.count") do
      assert_difference("get_nodes_templates_count") do
        assert_difference("Service.count") do
          post :create, :topology_id => @test_topology_id, :definition => inner_xml
          assert_response :success
        end
      end
    end
    assert_xml_equals get_response_element("node").to_s, inner_xml

    assert_difference("Node.count", -2) do
      assert_difference("Service.count", -1) do
        assert_difference("get_nodes_templates_count", -3) do
          post :destroy, :topology_id => @test_topology_id, :id => outer_id
          assert_response :success
        end
      end
    end
  end

  test "xml validation" do
    # create node by invalid xml
    get_invalid_nodes.each do |invalid_xml|
      assert_no_differences do
        post :create, :topology_id => @test_topology_id, :definition => invalid_xml
        assert_response :bad_request, "invalid xml passed the validation: #{invalid_xml}"
        assert_select "error_type", "XmlValidationError"
      end
    end

    # create node by valid xml
    get_valid_nodes.each do |xml|
      post :create, :topology_id => @test_topology_id, :definition => xml
      assert_response :success, "valid xml didn't pass the validation.\nXML: #{xml}\nResponse: #{@response.body}"
      id = Rails.application.routes.recognize_path(get_self_link)[:id]

      post :destroy, :topology_id => @test_topology_id, :id => id
      assert_response :success
    end
  end

  test "rename operation" do
    xml = '<node id="rename"/>'
    post :create, :topology_id => @test_topology_id, :definition => xml
    assert_response :success
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # rename the node to new_name
	xml = '<node id="new_name"/>'
    post :update, :topology_id => @test_topology_id, :id => id, 
         :operation => "rename", :name => "new_name"
    assert_response(:success)
    assert_xml_equals get_response_element("node").to_s, xml

    # in case the name is already taken
    post :update, :topology_id => @test_topology_id, :id => id,
         :operation => "rename", :name => "web_host"
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"
    get :show, :topology_id => @test_topology_id, :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("node").to_s, xml
  end

  test "add and remove template" do
    xml = '<node id="extend"></node>'
    post :create, :topology_id => @test_topology_id, :definition => xml
    assert_response(:success)
    assert_xml_equals get_response_element("node").to_s, xml
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # test add template
    xml = '<node id="extend"><use_template name="ec2_small_instance"/></node>'
    assert_difference("get_nodes_templates_count") do
      post :update, :topology_id => @test_topology_id, :operation => "add_template", :template => "ec2_small_instance", :id => id
      assert_response(:success)
    end
    assert_xml_equals get_response_element("node").to_s, xml

    # test the added template is not existing
    assert_no_difference("get_nodes_templates_count") do
      post :update, :topology_id => @test_topology_id, :operation => "add_template", :template => "not_existing", :id => id
      assert_response(:bad_request)
    end
    assert_select "error_type", "ParametersValidationError"

    # test remove template that is not existing
    assert_no_difference("get_nodes_templates_count") do
      post :update, :topology_id => @test_topology_id, :operation => "remove_template", :template => "not_existing", :id => id
      assert_response(:bad_request)
    end
    assert_select "error_type", "ParametersValidationError"

    # test remove template that is defined but haven't been added
    assert_no_difference("get_nodes_templates_count") do
      post :update, :topology_id => @test_topology_id, :operation => "remove_template", :template => "database_container", :id => id
      assert_response(:bad_request)
    end
    assert_select "error_type", "ParametersValidationError"

    # test remove template that is defined but haven't been added
    xml = '<node id="extend"/>'
    assert_difference("get_nodes_templates_count", -1) do
      post :update, :topology_id => @test_topology_id, :operation => "remove_template", :template => "ec2_small_instance", :id => id
      assert_response(:success)
    end
    assert_xml_equals get_response_element("node").to_s, xml
  end

  test "set and remove attribute operation" do
    xml = '<node id="attr"></node>'
    post :create, :topology_id => @test_topology_id, :definition => xml
    assert_response(:success)
    assert_xml_equals get_response_element("node").to_s, xml
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # test set attribute
    xml = '<node id="attr"><for_cloud>ec2</for_cloud></node>'
    post :update, :topology_id => @test_topology_id, :operation => "set_attribute", :attribute_key => "for_cloud", :attribute_value => "ec2", :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("node").to_s, xml

    # test set duplicated attribute
    xml = '<node id="attr"><for_cloud>openstack</for_cloud></node>'
    post :update, :topology_id => @test_topology_id, :operation => "set_attribute", :attribute_key => "for_cloud", :attribute_value => "openstack", :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("node").to_s, xml

    # test remove non-existing attribute
    post :update, :topology_id => @test_topology_id, :operation => "remove_attribute", :attribute_key => "non_exist", :id => id
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"
    post :show, :topology_id => @test_topology_id, :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("node").to_s, xml

    # test remove existing attribute
    xml = '<node id="attr"></node>'
    post :update, :topology_id => @test_topology_id, :operation => "remove_attribute", :attribute_key => "for_cloud", :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("node").to_s, xml
  end

  test "unknown operation" do
    post :update, :topology_id => @test_topology_id, :id => @test_node_id, :operation => "unknown"
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"
  end

  test "no permission" do
    @user = users(:user2)
    sign_out :user
    sign_in @user

    # verify the response when permission denied
    post :show, :topology_id => @test_topology_id, :id => @test_node_id
    assert_response(:forbidden)
    assert_select "error_type", "AccessDeniedError"

    node = Node.find(@test_node_id)
    post :index, :topology_id => @test_topology_id
    assert_response(:success)
    assert_select "nodes node[id='#{node.node_id}']", false
  end
end