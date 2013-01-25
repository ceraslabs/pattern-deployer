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

class TemplateTest < ActiveSupport::TestCase

  include RestfulHelper
  include TemplatesHelper

  def setup
    @user = users(:user1)
  end

  test "attributes validations" do
    # create valid container
    topology = topologies(:my_topology)
    template = topology.templates.create(:template_id => "id", :owner => @user)
    assert template.valid?, "valid template is not saved: #{template.errors.full_messages}"
    template.destroy

    # create without parent
    template = Template.create(:template_id => "id", :owner => @user)
    assert_equal template.errors.size, 1, "Unexpected number of errors: #{template.errors.full_messages}"
    assert template.errors[:topology].any?, "Error is not on the right attribute"

    # create without incomplete attributes
    template = topology.templates.create
    assert_equal template.errors.size, 2, "Unexpected number of errors: #{template.errors.full_messages}"
    assert template.errors[:template_id].any?, "No error on template_id"
    assert template.errors[:owner].any?, "No error on owner"
  end

  test "template id uniqueness within topology" do
    # create valid container
    topology = topologies(:my_topology)
    first_template = topology.templates.create(:template_id => "test_id", :owner => @user)
    assert first_template.valid?
    second_template = topology.templates.create(:template_id => "test_id", :owner => @user)
    assert !second_template.valid?, "template is saved with duplicated id within topology"
    another_topology = topologies(:other)
    third_template = another_topology.templates.create(:template_id => "test_id", :owner => @user)
    assert third_template.valid?

    first_template.destroy
    third_template.destroy
  end

  test "template operation" do
    topology = topologies(:my_topology)
    template = topology.templates.create(:template_id => "id", :owner => @user)

    # test rename
    assert_equal template.template_id, "id"
    template.rename("new_name")
    template.save
    assert_equal template.template_id, "new_name"

    # test extend
    base = topology.templates.create(:template_id => "base", :owner => @user)
    assert_difference("template.base_templates.size") do
      template.extend(base.template_id)
      template.save
    end
    inherit = template.base_template_inheritances.first
    assert inherit.template.id == template.id
    assert inherit.base_template.id == base.id

    assert_raise(ParametersValidationError) do
      template.extend(base.template_id)
      template.save
    end

    assert_raise(ActiveRecord::RecordNotFound) do
      template.extend("No existing id")
      template.save
    end

    # test unextend
    assert_difference("template.base_templates.size", -1) do
      template.unextend(base.template_id)
      template.save
    end
    assert template.base_template_inheritances.size, 0

    assert_raise(ParametersValidationError) do
      template.unextend(base.template_id)
      template.save
    end

    # test set/remove attribute
    assert_difference("template.attrs.size") do
      template.set_attr "key", "value"
      template.save
    end
    assert_equal template.attrs["key"], "value"
    assert_no_difference("template.attrs.size") do
      template.set_attr "key", "new_value"
      template.save
    end
    assert_equal template.attrs["key"], "new_value"
    assert_difference("template.attrs.size", -1) do
      template.remove_attr "key"
      template.save
    end
    assert !template.attrs.has_key?("key")
    assert_raise(ParametersValidationError) do
      template.remove_attr "key"
      template.save
    end
  end

  test "update template attributes and connections" do
    topology = topologies(:my_topology)

    xml = '<template id="test_template">
              <extend template="ec2_small_instance"/>
              <service name="virsh">
                <port_redirection protocol="tcp" from="3306" to="3306"/>
              </service>
              <test_attr>test</test_attr>
            </template>'
    xml = parse_xml(xml)

    template = nil
    assert_difference("Template.count") do
      template = create_template_scaffold xml, topology, @user
    end
    assert_equal template.base_templates.size, 0
    assert_equal template.services.size, 0
    assert_equal template.attrs.size, 0

    # test update template attributes
    template.update_template_attributes(xml)
    assert_equal template.base_templates.size, 0
    assert_equal template.services.size, 1
    assert_equal template.attrs.size, 1
    assert_equal template.attrs["test_attr"], "test"
    virsh = template.services.find_by_service_id("virsh")
    assert_equal virsh.properties.size, 1
    assert_xml_equals virsh.properties.first, '<port_redirection protocol="tcp" from="3306" to="3306"/>'

    # test update template connections
    template.update_template_connections(xml)
    assert_equal template.base_templates.size, 1
    assert_equal template.base_templates.first.id, templates(:m1_small).id
    assert_equal template.services.size, 1
    assert_equal template.attrs.size, 1

    template.destroy
  end

  test "permission" do
    template = templates(:m1_small)

    # resource owner has all permission
    user = users(:user1)
    ability = Ability.new(user)
    assert ability.can?(:show, template)
    assert ability.can?(:create, template)
    assert ability.can?(:destroy, template)
    assert ability.can?(:update, template)

    # normal user other than owner don't have permission
    user = users(:user2)
    ability = Ability.new(user)
    assert ability.cannot?(:show, template)
    assert ability.cannot?(:create, template)
    assert ability.cannot?(:destroy, template)
    assert ability.cannot?(:update, template)

    # admin has all permission regardless resource owner
    user = users(:admin)
    ability = Ability.new(user)
    assert ability.can?(:show, template)
    assert ability.can?(:create, template)
    assert ability.can?(:destroy, template)
    assert ability.can?(:update, template)
  end
end