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

class NodeTest < ActiveSupport::TestCase

  include RestfulHelper
  include NodesHelper

  def setup
    @user = users(:user1)
  end

  test "attributes validations" do
    # create node from topology
    topology = topologies(:my_topology)
    node = topology.nodes.create(:node_id => "id", :owner => @user)
    assert node.valid?
    assert_equal topology.id, node.topology.id
    node.destroy

    # create node from container
    container = containers(:web_host)
    node = container.nodes.create(:node_id => "id", :owner => @user)
    assert node.valid?
    assert_equal container.topology.id, node.topology.id
    node.destroy

    # create without parent
    node = Node.create(:node_id => "id", :owner => @user)
    assert_equal node.errors.size, 1, "Unexpected number of errors: #{node.errors.full_messages}"
    assert node.errors[:parent].any?, "Error is not on the right attribute"

    # create without incomplete attributes
    node = topology.nodes.create
    assert_equal node.errors.size, 2, "Unexpected number of errors: #{node.errors.full_messages}"
    assert node.errors[:node_id].any?, "No error on node_id"
    assert node.errors[:owner].any?, "No error on owner"
  end

  test "node id uniqueness within topology" do
    # create valid node
    topology = topologies(:my_topology)
    first_node = topology.nodes.create(:node_id => "test_id", :owner => @user)
    assert first_node.valid?
    second_node = topology.nodes.create(:node_id => "test_id", :owner => @user)
    assert !second_node.valid?, "node is saved with duplicated id within topology"
    another_topology = topologies(:other)
    third_node = another_topology.nodes.create(:node_id => "test_id", :owner => @user)
    assert third_node.valid?

    first_node.destroy
    third_node.destroy
  end

  test "node operation" do
    # test rename
    node = nodes(:web_host)
    node.rename("new_web_host")
    assert node.save, "Can't rename"
    assert_equal node.node_id, "new_web_host", "new name #{node.node_id} is wrong"

    # test add/remove template
    template = templates(:m1_small)
    assert_difference("node.templates.size") do
      node.add_template template.template_id
      node.save
    end
    assert_equal node.templates.first.id, template.id
    assert_difference("node.templates.size", -1) do
      node.remove_template template.template_id
      node.save
    end

    # test set/remove attribute
    assert_difference("node.attrs.size") do
      node.set_attr "key", "value"
      node.save
    end
    assert_equal node.attrs["key"], "value"
    assert_no_difference("node.attrs.size") do
      node.set_attr "key", "new_value"
      node.save
    end
    assert_equal node.attrs["key"], "new_value"
    assert_difference("node.attrs.size", -1) do
      node.remove_attr "key"
      node.save
    end
    assert !node.attrs.has_key?("key")
  end

  test "create node scaffold" do
    topology = topologies(:my_topology)
    node = topology.nodes.create(:node_id => "test", :owner => @user)

    # valid xml
    xml = '<node id="test_create"/>'
    node = create_node_scaffold parse_xml(xml), topology, @user
    assert_equal node.node_id, "test_create"
    assert_equal node.attrs.size, 0
    assert_equal topology.id, node.topology.id
    assert_equal node.owner.id, @user.id
    node.destroy

    # invalid xml
    xml = 'invalid <node id="test_create"/>'
    assert_raise(XmlValidationError) do
      node = create_node_scaffold parse_xml(xml), topology, @user
    end

    xml = '<invalid id="test_create"/>'
    assert_raise(XmlValidationError) do
      node = create_node_scaffold parse_xml(xml), topology, @user
    end

    xml = '<node invalid="test_create"/>'
    assert_raise(XmlValidationError) do
      node = create_node_scaffold parse_xml(xml), topology, @user
    end
  end
  
  test "update node attributes and connections" do
    topology = topologies(:my_topology)
    node = topology.nodes.create(:node_id => "test", :owner => @user)

    xml = ' <node id="test_node">
               <use_template name="ec2_small_instance"/>
               <service name="openvpn_client">
                 <openvpn_server node="data_host"/>
               </service>
               <service name="virsh">
                 <port_redirection protocol="tcp" from="3306" to="3306"/>
               </service>
               <nest_within node="web_host"/>
               <test_attr>test</test_attr>
             </node>'
    xml = parse_xml(xml)

    assert_difference("Node.count") do
      node = create_node_scaffold xml, topology, @user
    end
    assert_equal node.templates.size, 0
    assert_equal node.services.size, 0
    assert_equal node.attrs.size, 0
    assert_equal node.container_node, nil

    # test update node attributes
    node.update_node_attributes(xml)
    assert_equal node.templates.size, 0
    assert_equal node.services.size, 2
    assert_equal node.attrs.size, 1
    assert_equal node.attrs["test_attr"], "test"
    assert_equal node.container_node, nil
    openvpn_client = node.services.find_by_service_id("openvpn_client")
    assert_equal openvpn_client.properties.size, 0
    assert_equal openvpn_client.nodes.size, 0
    assert_equal openvpn_client.service_to_node_refs.size, 0
    virsh = node.services.find_by_service_id("virsh")
    assert_equal virsh.properties.size, 1
    assert_xml_equals virsh.properties.first, '<port_redirection protocol="tcp" from="3306" to="3306"/>'
    assert_equal virsh.nodes.size, 0
    assert_equal virsh.service_to_node_refs.size, 0

    # test update node connections
    node.update_node_connections(xml)
    assert_equal node.templates.size, 1
    assert_equal node.templates.first.id, templates(:m1_small).id
    assert_equal node.services.size, 2
    assert_equal node.attrs.size, 1
    web_host = nodes(:web_host)
    assert_equal node.container_node.id, web_host.id
    assert_equal web_host.nested_nodes.size, 1
    assert_equal web_host.nested_nodes.first.id, node.id
    openvpn_client = node.services.find_by_service_id("openvpn_client")
    assert_equal openvpn_client.properties.size, 0
    assert_equal openvpn_client.nodes.size, 1
    assert_equal openvpn_client.nodes.first.id, nodes(:data_host).id
    assert_equal openvpn_client.service_to_node_refs.size, 1
    assert_equal openvpn_client.service_to_node_refs.first.ref_name, "openvpn_server"
    virsh = node.services.find_by_service_id("virsh")
    assert_equal virsh.properties.size, 1
    assert_equal virsh.nodes.size, 0
    assert_equal virsh.service_to_node_refs.size, 0

    node.destroy
    web_host.reload
    assert_equal web_host.nested_nodes.size, 0
  end

  test "permission" do
    node = nodes(:web_host)

    # resource owner has all permission
    user = users(:user1)
    ability = Ability.new(user)
    assert ability.can?(:show, node)
    assert ability.can?(:create, node)
    assert ability.can?(:destroy, node)
    assert ability.can?(:update, node)

    # normal user other than owner don't have permission
    user = users(:user2)
    ability = Ability.new(user)
    assert ability.cannot?(:show, node)
    assert ability.cannot?(:create, node)
    assert ability.cannot?(:destroy, node)
    assert ability.cannot?(:update, node)

    # admin has all permission regardless resource owner
    user = users(:admin)
    ability = Ability.new(user)
    assert ability.can?(:show, node)
    assert ability.can?(:create, node)
    assert ability.can?(:destroy, node)
    assert ability.can?(:update, node)
  end
end