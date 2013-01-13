require 'test_helper'

class TopologiesControllerTest < ActionController::TestCase

  include Devise::TestHelpers
  include RestfulHelper

  def setup
    @user = users(:user1)
    sign_in @user
    @test_topology_id = 1
  end

  def teardown
    sign_out :user
  end

  test "create by name" do
    # test create an topology
    assert_difference("Topology.count") do
      post :create, :name => "test", :description => "This is a test"
      assert_response :success
    end
    assert_xml_equals get_response_element("topology").to_s, '<topology id="test"><description>This is a test</description></topology>'
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # test get the created topology
    post :show, :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("topology").to_s, '<topology id="test"><description>This is a test</description></topology>'

    # test index the created topology
    post :index
    assert_response(:success)
    assert_select "topology[id='test']", true

    # test destroy the topology
    assert_difference("Topology.count", -1) do
      post :destroy, :id => id
      assert_response :success
    end
  end
  
  test "create by xml" do
    # valid create
    xml = '<topology id="basic_xml"><description>This is a test</description></topology>'
    assert_difference("Topology.count") do
      post :create, :topology_id => @test_topology_id, :definition => xml
      assert_response :success
    end
    assert_xml_equals get_response_element("topology").to_s, xml
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    diffs = {"Topology.count" => 1,
             "Container.count" => 1,
             "Node.count" => 3,
             "Template.count" => 7,
             "Service.count" => 3,
             "TemplateInheritance.count" => 5,
             "ServiceToNodeRef.count" => 2,
             "get_nodes_templates_count" => 3}
    file = fixture_file_upload("files/basic_mvc.xml", "application/xml")
    File.open(file.path, "r") do |input|
      xml = input.read
    end
    assert_differences(diffs) do
      post :create, :file => file
      assert_response :success
    end
    assert_xml_equals get_response_element("topology").to_s, xml
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    diffs = {"Topology.count" => -1,
             "Container.count" => -1,
             "Node.count" => -3,
             "Template.count" => -7,
             "Service.count" => -3,
             "TemplateInheritance.count" => -5,
             "ServiceToNodeRef.count" => -2,
             "get_nodes_templates_count" => -3}
    assert_differences(diffs) do
      post :destroy, :id => id
      assert_response :success
    end
  end

  test "xml validation" do
    # create topology by invalid xml
    get_invalid_topologies.each do |invalid_xml|
      assert_no_differences do
        post :create, :definition => invalid_xml
        assert_response :bad_request, "invalid xml passed the validation: #{invalid_xml}"
        assert_select "error_type", "XmlValidationError"
      end
    end

    # create topology by valid xml
    get_valid_topologies.each do |xml|
      post :create, :topology_id => @test_topology_id, :definition => xml
      assert_response :success, "valid xml didn't pass the validation.\nXML: #{xml}\nResponse: #{@response.body}"
      id = Rails.application.routes.recognize_path(get_self_link)[:id]

      post :destroy, :id => id
      assert_response :success
    end
  end

  test "rename operation" do
    xml = '<topology id="test_rename"></topology>'
    post :create, :definition => xml
    assert_response :success
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # rename the topology to web_server
	xml = '<topology id="new_name"/>'
    post :update, :id => id, :operation => "rename", :name => "new_name"
    assert_response(:success)
    assert_xml_equals get_response_element("topology").to_s, xml

    # rename the topology to an duplicated name
    post :update, :id => id, :operation => "rename", :name => "my_topology"
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"
    get :show, :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("topology").to_s, xml

    # rename but with name missing
    post :update, :id => id, :operation => "rename"
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"
    get :show, :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("topology").to_s, xml
  end

  test "update description operation" do
    xml = '<topology id="test"></topology>'
    post :create, :definition => xml
    assert_response :success
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # update_description the topology to web_server
    xml = '<topology id="test"><description>this is a new description</description></topology>'
    post :update, :id => id, :operation => "update_description", :description => "this is a new description"
    assert_response(:success)
    assert_xml_equals get_response_element("topology").to_s, xml

    xml = '<topology id="test"><description>this is a updated description</description></topology>'
    post :update, :id => id, :operation => "update_description", :description => "this is a updated description"
    assert_response(:success)
    assert_xml_equals get_response_element("topology").to_s, xml

    # update_description but with description missing
    post :update, :id => id, :operation => "update_description"
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"
    get :show, :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("topology").to_s, xml
  end

  test "unknown operation" do
    post :update, :id => @test_topology_id, :operation => "unknown"
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"
  end

  test "no permission" do
    @user = users(:user2)
    sign_out :user
    sign_in @user

    # verify the response when permission denied
    post :show, :id => @test_topology_id
    assert_response(:forbidden)
    assert_select "error_type", "AccessDeniedError"

    topology = Topology.find(@test_topology_id)
    post :index
    assert_response(:success)
    assert_select "topologies topology[id='#{topology.topology_id}']", false
  end
end

