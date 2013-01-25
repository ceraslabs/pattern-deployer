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

class ServiceTest < ActiveSupport::TestCase

  include RestfulHelper
  include ServicesHelper

  def setup
    @user = users(:user1)
  end

  test "attributes validations" do
    # create node from template
    template = templates(:db_container)
    service = template.services.create(:service_id => "web_server", :owner => @user)
    assert service.valid?
    assert_equal template.topology.id, service.topology.id
    service.destroy

    # create service from node
    node = nodes(:web_host)
    service = node.services.create(:service_id => "web_server", :owner => @user)
    assert service.valid?
    assert_equal node.topology.id, service.topology.id
    service.destroy

    # create without incomplete attributes
    service = Service.create
    assert_equal service.errors.size, 3, "Unexpected number of errors: #{service.errors.full_messages}"
    assert service.errors[:service_id].any?, "No error on service_id"
    assert service.errors[:owner].any?, "No error on owner"
    assert service.errors[:service_container].any?, "No error on service_container"

    # create node from template
    template = templates(:db_container)
    service = template.services.create(:service_id => "invalid_service", :owner => @user)
    assert_equal service.errors.size, 1, "Unexpected number of errors: #{service.errors.full_messages}"
    assert service.errors[:service_id].any?, "No error on service_id"
  end

  test "rename operation" do
    node = nodes(:web_host)
    service = node.services.create(:service_id => "web_server", :owner => @user)
    service.rename("database_server")
    assert service.save, "Renamed service is not saved: #{service.errors.full_messages}"
    assert_equal service.service_id, "database_server"

    assert_raise(ActiveRecord::RecordInvalid) do
      service.rename("invalid_service")
    end
    service.reload
    assert_equal service.service_id, "database_server"

    service.destroy
  end

  test "create service scaffold" do
    node = nodes(:data_host)
    topology = node.parent
    service = node.services.create(:service_id => "web_server", :owner => @user)

    # valid xml
    xml = '<service name="ossec_client"/>'
    service = create_service_scaffold parse_xml(xml), node, @user
    assert_equal service.service_id, "ossec_client"
    assert_equal service.properties.size, 0
    assert_equal service.nodes.size, 0
    assert_equal node.topology.id, service.topology.id
    service.destroy

    # invalid xml
    xml = 'invalid <service name="ossec_client"/>'
    assert_raise(XmlValidationError) do
      service = create_service_scaffold parse_xml(xml), node, @user
    end

    xml = '<invalid name="ossec_client"/>'
    assert_raise(XmlValidationError) do
      service = create_service_scaffold parse_xml(xml), node, @user
    end

    xml = '<service invalid="ossec_client"/>'
    assert_raise(XmlValidationError) do
      service = create_service_scaffold parse_xml(xml), node, @user
    end
  end

  test "valid redefine" do
    node = nodes(:data_host)
    topology = node.parent
    service = node.services.create(:service_id => "web_server", :owner => @user)

    xml = '<service name="ossec_client"/>'
    service.redefine parse_xml(xml)
    assert_equal service.service_id, "ossec_client"
    assert_equal service.properties.size, 0
    assert_equal service.nodes.size, 0

    xml = '<service name="virsh"><port_redirection protocol="tcp" from="3306" to="3306"/></service>'
    service.redefine parse_xml(xml)
    assert_equal service.service_id, "virsh"
    assert_equal service.properties.size, 1
    assert_xml_equals service.properties.first, '<port_redirection protocol="tcp" from="3306" to="3306"/>'
    assert_equal service.nodes.size, 0

    xml = '<service name="openvpn_client"><openvpn_server node="web_host"/></service>'
    service.redefine parse_xml(xml)
    assert_equal service.service_id, "openvpn_client"
    assert_equal service.properties.size, 0
    assert_equal service.nodes.size, 1
    assert_equal service.nodes.first.id, nodes(:web_host).id
    assert_equal service.service_to_node_refs.size, 1
    assert_equal service.service_to_node_refs.first.ref_name, "openvpn_server"

    service.destroy
  end

  test "rollback on redefine" do
    node = nodes(:data_host)
    topology = node.parent
    service = node.services.create(:service_id => "web_server", :owner => @user)

    # invalid element name
    xml = '<invalid name="openvpn_client"><openvpn_server node="web_host"/></invalid>'
    assert_raise(XmlValidationError) do
      service.redefine parse_xml(xml)
    end
    service.reload
    assert_equal service.service_id, "web_server"
    assert_equal service.properties.size, 0
    assert_equal service.nodes.size, 0

    # ref node not exist
    xml = '<service name="openvpn_client"><openvpn_server node="invalid"/></service>'
    assert_raise(XmlValidationError) do
      service.redefine parse_xml(xml)
    end
    service.reload
    assert_equal service.service_id, "web_server"
    assert_equal service.properties.size, 0
    assert_equal service.nodes.size, 0

    service.destroy
  end

  test "permission" do
    service = services(:mysql)

    # resource owner has all permission
    user = users(:user1)
    ability = Ability.new(user)
    assert ability.can?(:show, service)
    assert ability.can?(:create, service)
    assert ability.can?(:destroy, service)
    assert ability.can?(:update, service)

    # normal user other than owner don't have permission
    user = users(:user2)
    ability = Ability.new(user)
    assert ability.cannot?(:show, service)
    assert ability.cannot?(:create, service)
    assert ability.cannot?(:destroy, service)
    assert ability.cannot?(:update, service)

    # admin has all permission regardless resource owner
    user = users(:admin)
    ability = Ability.new(user)
    assert ability.can?(:show, service)
    assert ability.can?(:create, service)
    assert ability.can?(:destroy, service)
    assert ability.can?(:update, service)
  end
end