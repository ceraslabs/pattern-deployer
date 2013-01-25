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

class TopologyTest < ActiveSupport::TestCase

  include RestfulHelper
  include TopologiesHelper

  def setup
    @user = users(:user1)
  end

  test "attribute validation" do
    # create valid topology
    topology = Topology.create(:topology_id => "id", :owner => @user)
    assert topology.valid?, topology.errors.full_messages
    assert_equal topology.state, State::UNDEPLOY
    topology.destroy

    # create without incomplete attributes
    topology = Topology.create
    assert_equal topology.errors.size, 2, "Unexpected number of errors: #{topology.errors.full_messages}"
    assert topology.errors[:topology_id].any?, "No error on topology_id"
    assert topology.errors[:owner].any?, "No error on owner"
	
    # verify topology_id is unique
    topology = Topology.create(:topology_id => "my_topology", :owner => @user)
    assert_equal topology.errors.size, 1, "Unexpected number of errors: #{topology.errors.full_messages}"
    assert topology.errors[:topology_id].any?, "No error on topology_id"

    # verify state cannot be invalid
    topology = Topology.create(:topology_id => "id", :owner => @user, :state => "invalid state")
    assert_equal topology.errors.size, 1, "Unexpected number of errors: #{topology.errors.full_messages}"
    assert topology.errors[:state].any?, "No error on state"
  end

  test "create topology scaffold" do
    # valid xml
    xml = '<topology id="test_topology"/>'
    topology = create_topology_scaffold parse_xml(xml), @user
    assert_equal topology.topology_id, "test_topology"
    assert_equal topology.owner.id, @user.id
    topology.destroy

    # invalid xml
    xml = 'invalid <topology id="test_topology"/>'
    assert_raise(XmlValidationError) do
      topology = create_topology_scaffold parse_xml(xml), @user
    end

    xml = '<invalid id="test_topology"/>'
    assert_raise(XmlValidationError) do
      topology = create_topology_scaffold parse_xml(xml), @user
    end

    xml = '<topology invalid="test_topology"/>'
    assert_raise(XmlValidationError) do
      topology = create_topology_scaffold parse_xml(xml), @user
    end
  end

  test "update topology attributes and connections" do
    xml = '
<topology id="myTopology">
  <description>This is a basic mvc pattern</description>
  <instance_templates>
    <template id="base_instance">
      <service name="ossec_client"/>
    </template>

    <template id="ec2_instance">
      <extend template="base_instance"/>
      <ssh_user>test_user</ssh_user>
    </template>
	<template id="container_instance">
      <extend template="base_instance"/>
      <service name="virsh"/>
    </template>
  </instance_templates>
  <node id="data_host">
    <use_template name="ec2_instance"/>
    <service name="database_server"/>
  </node>
  <node id="web_balancer">
    <use_template name="ec2_instance"/>
    <service name="web_balancer">
      <member node="inner_web_host"/>
    </service>
  </node>
  <container id="web_host_container" num_of_copies="2">
    <node id="web_host">
      <use_template name="ec2_instance"/>
      <use_template name="container_instance"/>
    </node>
    <node id="inner_web_host">
      <service name="web_server">
        <database node="data_host"/>
      </service>
      <nest_within node="web_host"/>
    </node>
  </container>
</topology>'
    xml = parse_xml(xml)

    topology = nil
    assert_difference("Topology.count") do
      topology = create_topology_scaffold xml, @user
    end
    assert_equal topology.topology_id, "myTopology"
    assert_equal topology.templates.size, 0
    assert_equal topology.containers.size, 0
    assert_equal topology.nodes.size, 0

    # test update topology attributes
    topology.update_topology_attributes(xml)
    assert_equal topology.description, "This is a basic mvc pattern"
    assert_equal topology.templates.size, 3
    assert_equal topology.containers.size, 1
    assert_equal topology.nodes.size, 2
    assert_equal topology.containers.first.nodes.size, 2

    base_template = topology.templates.find_by_template_id! "base_instance"
    assert_equal base_template.services.size, 1
    assert_equal base_template.services.first.service_id, "ossec_client"

    ec2_template = topology.templates.find_by_template_id "ec2_instance"
    assert_equal ec2_template.attrs.size, 1
    assert_equal ec2_template.attrs["ssh_user"], "test_user"
    assert_equal ec2_template.base_templates.size, 0

    container_template = topology.templates.find_by_template_id "container_instance"
    assert_equal container_template.services.size, 1
    assert_equal container_template.services.first.service_id, "virsh"
    assert_equal container_template.base_templates.size, 0

    data_node = topology.nodes.find_by_node_id "data_host"
    assert_equal data_node.services.size, 1
    assert_equal data_node.services.first.service_id, "database_server"
    assert_equal data_node.templates.size, 0

    balancer_node = topology.nodes.find_by_node_id "web_balancer"
    assert_equal balancer_node.services.size, 1
    assert_equal balancer_node.services.first.service_id, "web_balancer"
    assert_equal balancer_node.templates.size, 0

    web_container = topology.containers.find_by_container_id "web_host_container"
    assert_equal web_container.nodes.size, 2
    assert_equal web_container.num_of_copies, 2

    web_node = web_container.nodes.find_by_node_id "web_host"
    assert_equal web_node.services.size, 0
    assert_equal web_node.templates.size, 0

    inner_web_node = web_container.nodes.find_by_node_id "inner_web_host"
    assert_equal inner_web_node.services.size, 1
    assert_equal inner_web_node.templates.size, 0
    assert_equal inner_web_node.nested_nodes.size, 0

    # test update topology connections
    topology.update_topology_connections(xml)
    assert_equal topology.templates.size, 3
    assert_equal topology.containers.size, 1
    assert_equal topology.nodes.size, 2
    assert_equal topology.containers.first.nodes.size, 2

    ec2_template.reload
    assert_equal ec2_template.attrs.size, 1
    assert_equal ec2_template.base_templates.size, 1
    assert_equal ec2_template.base_templates.first.id, base_template.id

    container_template.reload
    assert_equal container_template.services.size, 1
    assert_equal container_template.base_templates.size, 1
    assert_equal container_template.base_templates.first.id, base_template.id

    data_node.reload
    assert_equal data_node.services.size, 1
    assert_equal data_node.templates.size, 1
    assert_equal data_node.templates.first.id, ec2_template.id

    balancer_node.reload
    assert_equal balancer_node.services.size, 1
    assert_equal balancer_node.services.first.nodes.size, 1
    assert_equal balancer_node.services.first.nodes.first.id, inner_web_node.id
    assert_equal balancer_node.templates.size, 1
    assert_equal balancer_node.templates.first.id, ec2_template.id

    web_node.reload
    assert_equal web_node.services.size, 0
    assert_equal web_node.templates.size, 2
    assert_equal web_node.templates.find_by_template_id!("ec2_instance").id, ec2_template.id
    assert_equal web_node.templates.find_by_template_id!("container_instance").id, container_template.id
    assert_equal web_node.nested_nodes.size, 1
    assert_equal web_node.nested_nodes.first.id, inner_web_node.id

    inner_web_node.reload
    assert_equal inner_web_node.services.size, 1
    assert_equal inner_web_node.services.first.nodes.size, 1
    assert_equal inner_web_node.services.first.nodes.first.id, data_node.id
    assert_equal inner_web_node.templates.size, 0
    assert_equal inner_web_node.nested_nodes.size, 0

    # test destroy
    assert_difference("Topology.count", -1) do
      topology.destroy
    end
    assert !Template.exists?(base_template)
    assert !Template.exists?(ec2_template)
    assert !Template.exists?(container_template)
    assert !Node.exists?(web_node)
    assert !Node.exists?(inner_web_node)
    assert !Node.exists?(data_node)
    assert !Node.exists?(balancer_node)
    assert !Container.exists?(web_container)
  end

  test "permission" do
    topology = topologies(:my_topology)

    # resource owner has all permission
    user = users(:user1)
    ability = Ability.new(user)
    assert ability.can?(:show, topology)
    assert ability.can?(:create, topology)
    assert ability.can?(:destroy, topology)
    assert ability.can?(:update, topology)

    # normal user other than owner don't have permission
    user = users(:user2)
    ability = Ability.new(user)
    assert ability.cannot?(:show, topology)
    assert ability.cannot?(:create, topology)
    assert ability.cannot?(:destroy, topology)
    assert ability.cannot?(:update, topology)

    # admin has all permission regardless resource owner
    user = users(:admin)
    ability = Ability.new(user)
    assert ability.can?(:show, topology)
    assert ability.can?(:create, topology)
    assert ability.can?(:destroy, topology)
    assert ability.can?(:update, topology)
  end
end