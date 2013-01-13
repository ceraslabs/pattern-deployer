require 'test_helper'

class TemplatesControllerTest < ActionController::TestCase

  include Devise::TestHelpers
  include RestfulHelper

  def setup
    @user = users(:user1)
    sign_in @user
    @test_topology_id = 1
    @test_template_id = 1
  end

  def teardown
    sign_out :user
  end

  test "create by name" do
    # test create an template
    assert_difference("Template.count") do
      post :create, :name => "test", :topology_id => @test_topology_id
      assert_response :success
    end
    assert_xml_equals get_response_element("template").to_s, '<template id="test"/>'
    new_template_id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # test get the created template
    post :show, :topology_id => @test_topology_id, :id => new_template_id
    assert_response(:success)
    assert_xml_equals get_response_element("template").to_s, '<template id="test"/>'

    # test index the created template
    post :index, :topology_id => @test_topology_id, :node_id => @test_node_id
    assert_response(:success)
    assert_xml_equals get_response_element("//template[@id='test']").to_s, '<template id="test"/>'

    # test destroy the template
    assert_difference("Template.count", -1) do
      post :destroy, :topology_id => @test_topology_id, :id => new_template_id
      assert_response :success
    end
  end
  
  test "create by xml" do
    # valid create
    base_xml = '<template id="test_base_instance"><service name="ossec_client"/></template>'
    assert_difference("Template.count") do
	  assert_difference("Service.count") do
        post :create, :topology_id => @test_topology_id, :definition => base_xml
        assert_response :success
      end
    end
    assert_xml_equals get_response_element("template").to_s, base_xml
    base_template_id = Rails.application.routes.recognize_path(get_self_link)[:id]

    ec2_xml = '<template id="test_ec2_instance">
      <extend template="test_base_instance"/>
      <for_cloud>EC2</for_cloud>
      <ssh_user>ubuntu</ssh_user>
    </template>'
    assert_difference("Template.count") do
      assert_difference("TemplateInheritance.count") do
        post :create, :topology_id => @test_topology_id, :definition => ec2_xml
        assert_response :success
      end
    end
    assert_xml_equals get_response_element("template").to_s, ec2_xml
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    assert_difference("Template.count", -2) do
      assert_difference("TemplateInheritance.count", -1) do
        post :destroy, :topology_id => @test_topology_id, :id => base_template_id
        assert_response :success
      end
    end
  end

  test "xml validation" do
    # create template by invalid xml
    get_invalid_templates.each do |invalid_xml|
      assert_no_differences do
        post :create, :topology_id => @test_topology_id, :node_id => @test_node_id, :definition => invalid_xml
        assert_response :bad_request, "invalid xml passed the validation: #{invalid_xml}"
        assert_select "error_type", "XmlValidationError"
      end
    end

    # create template by valid xml
    get_valid_templates.each do |xml|
      post :create, :topology_id => @test_topology_id, :node_id => @test_node_id, :definition => xml
      assert_response :success, "valid xml didn't pass the validation.\nXML: #{xml}\nResponse: #{@response.body}"
      id = Rails.application.routes.recognize_path(get_self_link)[:id]

      post :destroy, :topology_id => @test_topology_id, :id => id
      assert_response :success
    end
  end

  test "rename operation" do
    xml = '<template id="rename"><service name="ossec_client"/></template>'
    post :create, :topology_id => @test_topology_id, :definition => xml
    assert_response :success
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # rename the template to web_server
	xml = '<template id="web_server"><service name="ossec_client"/></template>'
    post :update, :topology_id => @test_topology_id, :id => id, 
         :operation => "rename", :name => "web_server"
    assert_response(:success)
    assert_xml_equals get_response_element("template").to_s, xml

    # rename the template to an duplicated name
    post :update, :topology_id => @test_topology_id, :id => id,
         :operation => "rename", :name => "ec2_small_instance"
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"
    get :show, :topology_id => @test_topology_id, :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("template").to_s, xml
  end

  test "extend and unextend operation" do
    xml = '<template id="extend"></template>'
    post :create, :topology_id => @test_topology_id, :definition => xml
    assert_response(:success)
    assert_xml_equals get_response_element("template").to_s, xml
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # test extend
    xml = '<template id="extend"><extend template="ec2_small_instance"/></template>'
    assert_difference("TemplateInheritance.count") do
      post :update, :topology_id => @test_topology_id, :operation => "extend", :base_template => "ec2_small_instance", :id => id
      assert_response(:success)
    end
    assert_xml_equals get_response_element("template").to_s, xml

    # test invalid extend
    invalid_xml = '<template id="extend"><extend template="invalid"/></template>'
    assert_no_difference("TemplateInheritance.count") do
      post :update, :topology_id => @test_topology_id, :operation => "extend", :base_template => "invalid", :id => id
      assert_response(:bad_request)
    end
    assert_select "error_type", "ParametersValidationError"

    # test multiple extend
    xml = '<template id="extend"><extend template="ec2_small_instance"/><extend template="database_container"/></template>'
    assert_difference("TemplateInheritance.count") do
      post :update, :topology_id => @test_topology_id, :operation => "extend", :base_template => "database_container", :id => id
      assert_response(:success)
    end
    assert_xml_equals get_response_element("template").to_s, xml

    # test unextend extend
    xml = '<template id="extend"><extend template="database_container"/></template>'
    assert_difference("TemplateInheritance.count", -1) do
      post :update, :topology_id => @test_topology_id, :operation => "unextend", :base_template => "ec2_small_instance", :id => id
      assert_response(:success)
    end
    assert_xml_equals get_response_element("template").to_s, xml
  end

  test "set and remove attribute operation" do
    xml = '<template id="attr"></template>'
    post :create, :topology_id => @test_topology_id, :definition => xml
    assert_response(:success)
    assert_xml_equals get_response_element("template").to_s, xml
    id = Rails.application.routes.recognize_path(get_self_link)[:id]

    # test set attribute
    xml = '<template id="attr"><for_cloud>ec2</for_cloud></template>'
    post :update, :topology_id => @test_topology_id, :operation => "set_attribute", :attribute_key => "for_cloud", :attribute_value => "ec2", :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("template").to_s, xml

    # test set duplicated attribute
    xml = '<template id="attr"><for_cloud>openstack</for_cloud></template>'
    post :update, :topology_id => @test_topology_id, :operation => "set_attribute", :attribute_key => "for_cloud", :attribute_value => "openstack", :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("template").to_s, xml

    # test remove non-existing attribute
    post :update, :topology_id => @test_topology_id, :operation => "remove_attribute", :attribute_key => "non_exist", :id => id
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"
    post :show, :topology_id => @test_topology_id, :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("template").to_s, xml

    # test remove existing attribute
    xml = '<template id="attr"></template>'
    post :update, :topology_id => @test_topology_id, :operation => "remove_attribute", :attribute_key => "for_cloud", :id => id
    assert_response(:success)
    assert_xml_equals get_response_element("template").to_s, xml
  end

  test "unknown operation" do
    post :update, :topology_id => @test_topology_id, :id => @test_template_id, :operation => "unknown"
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"
  end

  test "no permission" do
    @user = users(:user2)
    sign_out :user
    sign_in @user

    # verify the response when permission denied
    post :show, :topology_id => @test_topology_id, :id => @test_template_id
    assert_response(:forbidden)
    assert_select "error_type", "AccessDeniedError"

    template = Template.find(@test_template_id)
    post :index, :topology_id => @test_topology_id
    assert_response(:success)
    assert_select "templates template[id='#{template.template_id}']", false
  end
end
