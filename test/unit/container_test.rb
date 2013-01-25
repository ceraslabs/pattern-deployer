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

class ContainerTest < ActiveSupport::TestCase

  include RestfulHelper
  include ContainersHelper

  def setup
    @user = users(:user1)
  end

  test "attributes validations" do
    # create valid container
    topology = topologies(:my_topology)
    container = topology.containers.create(:container_id => "id", :owner => @user)
    assert container.valid?, container.errors.full_messages
    assert_equal container.num_of_copies, 1, "default number of copies is not 1"
    container.destroy

    # create valid container with num_of_copies
    topology = topologies(:my_topology)
    container = topology.containers.create(:container_id => "id", :num_of_copies => "2", :owner => @user)
    assert container.valid?, container.errors.full_messages
    assert_equal container.num_of_copies, 2, "number of copies is not 2"
    container.destroy

    # create without topology
    container = Container.create(:container_id => "id", :owner => @user)
    assert_equal container.errors.size, 1, "Unexpected number of errors"
    assert container.errors[:topology].any?, "Error is not on the right attribute"

    # create without container_id
    container = topology.containers.create(:owner => @user)
    assert_equal container.errors.size, 1, "Unexpected number of errors"
    assert container.errors[:container_id].any?, "Error is not on the right attribute"

    # create without owner
    container = topology.containers.create(:container_id => "id")
    assert_equal container.errors.size, 1, "Unexpected number of errors"
    assert container.errors[:owner].any?, "Error is not on the right attribute"

    # create with invalid number of copies
    container = topology.containers.create(:container_id => "id", :owner => @user, :num_of_copies => "not_number")
    assert_equal container.errors.size, 1, "Unexpected number of errors"
    assert container.errors[:num_of_copies].any?, "Error is not on the right attribute"
  end

  test "container id uniqueness within topology" do
    # create valid container
    topology = topologies(:my_topology)
    first_container = topology.containers.create(:container_id => "test_id", :owner => @user)
    assert first_container.valid?
    second_container = topology.containers.create(:container_id => "test_id", :owner => @user)
    assert !second_container.valid?, "container is saved with duplicated id within topology"
    another_topology = topologies(:other)
    third_container = another_topology.containers.create(:container_id => "test_id", :owner => @user)
    assert third_container.valid?

    first_container.destroy
    third_container.destroy
  end

  test "create container scaffold" do
    topology = topologies(:my_topology)

    # valid xml
    xml = '<container id="test" num_of_copies="2"/>'
    container = create_container_scaffold parse_xml(xml), topology, @user
    assert_equal container.container_id, "test"
    assert_equal container.num_of_copies, 2
    assert_equal container.topology.id, topology.id
    assert_equal container.owner.id, topology.owner.id
    container.destroy

    # invalid xml
    xml = 'invalid <container id="test"/>'
    assert_raise(XmlValidationError) do
      container = create_container_scaffold parse_xml(xml), topology, @user
    end

    xml = '<invalid id="test"/>'
    assert_raise(XmlValidationError) do
      container = create_container_scaffold parse_xml(xml), topology, @user
    end

    xml = '<container invalid="test"/>'
    assert_raise(XmlValidationError) do
      container = create_container_scaffold parse_xml(xml), topology, @user
    end
  end

  test "update container attributes and connections" do
    topology = topologies(:my_topology)

    xml = '<container id="test_host_container">
             <node id="test_host">
               <use_template name="ec2_small_instance"/>
             </node>
             <node id="inner_test_host">
               <nest_within node="test_host"/>
               <service name="web_server"/>		   
               <ssh_user>test_user</ssh_user>
               <password>test_pwd</password>
             </node>
           </container>'
    xml = parse_xml(xml)

    container = nil
    assert_difference("Container.count") do
      container = create_container_scaffold xml, topology, @user
    end
    assert_equal container.container_id, "test_host_container"
    assert_equal container.num_of_copies, 1

    # update attributes
    assert_difference("Node.count", 2) do
      container.update_container_attributes(xml)
    end
    test_host = container.nodes.find_by_node_id("test_host")
    assert_equal test_host.services.size, 0
    assert_equal test_host.attrs.size, 0
    assert_equal test_host.templates.size, 0
    assert_equal test_host.container_node, nil
    assert_equal test_host.nested_nodes.size, 0

    inner_test_host = container.nodes.find_by_node_id("inner_test_host")
    assert_equal inner_test_host.services.size, 1
    assert_equal inner_test_host.services.first.service_id, "web_server"
    assert_equal inner_test_host.attrs.size, 2
    assert_equal inner_test_host.attrs["ssh_user"], "test_user"
    assert_equal inner_test_host.attrs["password"], "test_pwd"
    assert_equal inner_test_host.templates.size, 0
    assert_equal inner_test_host.container_node, nil
    assert_equal inner_test_host.nested_nodes.size, 0

    # update connections
    container.update_container_connections(xml)
    test_host.reload
    assert_equal test_host.services.size, 0
    assert_equal test_host.attrs.size, 0
    assert_equal test_host.templates.size, 1
    assert_equal test_host.templates.first.id, templates(:m1_small).id
    assert_equal test_host.container_node, nil
    assert_equal test_host.nested_nodes.size, 1
    assert_equal test_host.nested_nodes.first.id, inner_test_host.id

    inner_test_host.reload
    assert_equal inner_test_host.services.size, 1
    assert_equal inner_test_host.attrs.size, 2
    assert_equal inner_test_host.templates.size, 0
    assert_equal inner_test_host.container_node.id, test_host.id
    assert_equal inner_test_host.nested_nodes.size, 0
	
    assert Node.exists?(test_host)
    assert Node.exists?(inner_test_host)
    container.destroy
    assert container.destroyed?
    assert !Node.exists?(test_host)
    assert !Node.exists?(inner_test_host)
  end

  test "permission" do
    container = containers(:web_host)

    # resource owner has all permission
    user = users(:user1)
    ability = Ability.new(user)
    assert ability.can?(:show, container)
    assert ability.can?(:create, container)
    assert ability.can?(:destroy, container)
    assert ability.can?(:update, container)

    # normal user other than owner don't have permission
    user = users(:user2)
    ability = Ability.new(user)
    assert ability.cannot?(:show, container)
    assert ability.cannot?(:create, container)
    assert ability.cannot?(:destroy, container)
    assert ability.cannot?(:update, container)

    # admin has all permission regardless resource owner
    user = users(:admin)
    ability = Ability.new(user)
    assert ability.can?(:show, container)
    assert ability.can?(:create, container)
    assert ability.can?(:destroy, container)
    assert ability.can?(:update, container)
  end
end