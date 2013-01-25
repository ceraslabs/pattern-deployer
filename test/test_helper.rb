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
ENV["RAILS_ENV"] = "test"
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require "xml"

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.(yml|csv) for all tests in alphabetical order.
  #
  # Note: You'll currently still have to declare fixtures explicitly in integration tests
  # -- they do not yet inherit this setting
  fixtures :all

  # Add more helper methods to be used by all tests here...

  def assert_xml_equals(first_xml, second_xml)
    doc1 = XML::Document.string(first_xml)
    doc2 = XML::Document.string(second_xml)

    assert_block "'#{first_xml}' is not the same as '#{second_xml}'" do
      tree_equals?(doc1.root, doc2.root)
    end
  end

  def assert_differences(diffs, &proc)
    curr_proc = proc
    diffs.each do |expr, diff|
      curr_proc = assert_differences_helper(expr, diff, curr_proc)
    end

    curr_proc.call
  end

  def assert_no_differences(&proc)
    exprs = ["Topology.count", "Container.count", "Node.count", "Template.count", "Service.count",
             "TemplateInheritance.count", "ServiceToNodeRef.count", "get_nodes_templates_count"]

    curr_proc = proc
    exprs.each do |expr|
      curr_proc = assert_differences_helper(expr, 0, curr_proc)
    end

    curr_proc.call
  end

  def assert_have_values(elements, values)
    values.each do |value|
      found = false
      elements.each do |element|
        if element.content.strip == value
          found = true
          break
        end
      end

      assert_block "'#{value}' is expected to have but it is not found" do
        found
      end
    end
  end

  def assert_not_have_values(elements, values)
    values.each do |value|
      elements.each do |element|
        assert_block "'#{value}' is not expected to have but it is found" do
          element.content.strip != value
        end
      end
    end
  end

  def get_response_element(element_name)
    doc = parse_xml(@response.body)
    doc.find_first(element_name)
  end

  def get_response_elements(element_name)
    doc = parse_xml(@response.body)
    doc.find(element_name)
  end

  def get_self_link
    doc = parse_xml(@response.body)
    doc.find_first("links/link[@resource='self']").content
  end

  def get_nodes_templates_count
    ActiveRecord::Base.connection.execute('select * from nodes_templates').size
  end

  def get_invalid_services
    ['<service/>', # service must have an 'name' attribute
     '<service id="database_server"/>', # service must have an 'name' attribute
     '<service name="invalid_service"/>', # service name is invalid
     '<service name="database_server"><database node="non_existing_node"/></service>' # service reference an non existing node
    ] 
  end

  def get_valid_services(options={})
    valid_services = ['<service name="web_server"/>',
     '<service name="web_server"><port_redirection protocol="tcp" from="3306" to="3306"/></service>'
     ]

    if options[:with_connection]
      valid_services << '<service name="web_server"><database node="data_host"/></service>'
    end

    valid_services
  end

  def get_invalid_templates
    invalid_templates = ['<template/>', # template must have an 'id' attribute
      '<template name="invalid_template"/>', # template must have an 'id' attribute
      '<template id="ec2_small_instance"/>', # template id is taken
      '<template id="invalid_template"><invalid/></template>', # child element of template is invalid
      '<template id="invalid_template"><attribute>value<inavlid/></attribute></template>', # child element of template is invalid
      '<template id="invalid_template"><service name="web_server"><database node="data_host"/></service></template>', # service inside template should not have connection
      '<template id="invalid_template"><extend/></template>', # extend must have an 'template' attribute
      '<template id="invalid_template"><extend id="ec2_small_instance"/></template>', # extend must have an 'template' attribute
      '<template id="invalid_template"><extend template="non_exist"/></template>', # extend an non_existing template
      '<template id="invalid_template"><extend template="invalid_template"/></template>', # template should not extend itself
      '<template id="invalid_template"><extend template="ec2_small_instance"/><extend template="ec2_small_instance"/></template>'] # template should not extend the same template twice

    # template that contains an invalid service definition is also invalid
    get_invalid_services.each do |invalid_service|
      invalid_templates << '<template id="invalid_template">' + invalid_service + '</template>'
    end

    invalid_templates
  end

  def get_valid_templates
    valid_templates = ['<template id="valid_template"/>',
      '<template id="valid_template"><attribute>value</attribute></template>',
      '<template id="valid_template"><service name="web_server"></service></template>',
      '<template id="valid_template"><extend template="ec2_small_instance"/></template>',
      '<template id="valid_template"><extend template="ec2_small_instance"/><extend template="database_container"/></template>']

    # template that contains an valid service definition is also valid
    get_valid_services.each do |valid_service|
      valid_templates << '<template id="valid_template">' + valid_service + '</template>'
    end

    valid_templates
  end

  def get_invalid_nodes
    invalid_nodes = ['<node/>', # node must have an 'id' attribute
      '<node name="invalid_node"/>', # node must have an 'id' attribute
      '<node id="data_host"/>', # node id is taken
      '<node id="invalid_node"><invalid/></node>', # child element of node is invalid
      '<node id="invalid_node"><attribute>value<inavlid/></attribute></node>', # child element of node is invalid
      '<node id="invalid_node"><use_template/></node>', # use_template element should have an name attribute
      '<node id="invalid_node"><use_template id="ec2_small_instance"/></node>', # use_template element should have an name attribute
      '<node id="invalid_node"><use_template name="non_existing"/></node>', # The used template must exist
      '<node id="invalid_node"><use_template name="ec2_small_instance"/><use_template name="ec2_small_instance"/></node>', # The same template should not be used twice
      '<node id="invalid_node"><nest_within/></node>', # nest_within element must specify an attribute 'node'
      '<node id="invalid_node"><nest_within id="data_host"/></node>', # nest_within element must specify an attribute 'node'
      '<node id="invalid_node"><nest_within node="non_existing"/></node>', # nest_within element must ref to an existing node
      '<node id="invalid_node"><nest_within node="data_host"/><nest_within node="web_host"/></node>', # an node should not nest_with more than one node
      '<node id="invalid_node"><nest_within node="invalid_node"/></node>'] # A node cannot nest within itself

    # node that contains an invalid service definition is also invalid
    get_invalid_services.each do |invalid_service|
      invalid_nodes << '<node id="invalid_node">' + invalid_service + '</node>'
    end

    invalid_nodes
  end

  def get_valid_nodes
    valid_nodes = ['<node id="valid_node"/>',
      '<node id="valid_node"><attribute>value</attribute></node>',
      '<node id="valid_node"><use_template name="ec2_small_instance"/></node>',
      '<node id="valid_node"><nest_within node="data_host"/></node>']

    # node that contains an valid service definition is also valid
    get_valid_services(:with_connection => true).each do |valid_service|
      valid_nodes << '<node id="valid_node">' + valid_service + '</node>'
    end

    valid_nodes
  end

  def get_invalid_containers
    invalid_containers = ['<container/>', # container must have an 'id' attribute
      '<container name="invalid_container"/>', # container must have an 'id' attribute
      '<container id="web_host_container"/>', # container id is taken
      '<container id="invalid_container"><invalid/></container>',
      '<container id="invalid_container" num_of_copies="not_a_number"></container>'] # num_of_copies must be a number

    # container that contains an invalid node definition is also invalid
    get_invalid_nodes.each do |invalid_nodes|
      invalid_containers << '<container id="invalid_container">' + invalid_nodes + '</container>'
    end

    invalid_containers
  end

  def get_valid_containers
    valid_containers = ['<container id="valid_container"/>',
      '<container id="valid_container" num_of_copies="2"></container>']

    # container that contains an invalid node definition is also invalid
    get_valid_nodes.each do |valid_nodes|
      valid_containers << '<container id="valid_container">' + valid_nodes + '</container>'
    end

    valid_containers
  end

  def get_invalid_topologies
    invalid_topologies = ['<topology/>', # topology must have an 'id' attribute
      '<topology name="invalid_topology"/>', # topology must have an 'id' attribute
      '<topology id="my_topology"/>', # topology id is taken
      '<topology id="invalid_topology"><invalid/></topology>'] # child element must be valid

    # topology that contains an invalid template definition is also invalid
    get_invalid_templates.each do |invalid_template|
      invalid_topologies << '<topology id="invalid_topology"><instance_templates><template id="ec2_small_instance"/>' + invalid_template + '</instance_templates></topology>'
    end

    # this is used to create an duplicated id of node and container
    dup_elements ='<container id="web_host_container"/><node id="data_host"/>'
    # topology that contains an invalid node definition is also invalid
    get_invalid_nodes.each do |invalid_node|
      invalid_topologies << '<topology id="invalid_topology">' + dup_elements + invalid_node + '</topology>'
    end

    # topology that contains an invalid container definition is also invalid
    get_invalid_containers.each do |invalid_container|
      invalid_topologies << '<topology id="invalid_topology">' + dup_elements + invalid_container + '</topology>'
    end

    invalid_topologies
  end

  def get_valid_topologies
    valid_topologies = ['<topology id="valid_topology"/>',
      '<topology id="valid_topology"><description>This is a test</description></topology>']

    # topology that contains an valid template definition is also valid
    get_valid_templates.each do |valid_template|
      valid_topologies << '<topology id="valid_topology"><instance_templates><template id="ec2_small_instance"/><template id="database_container"/>' + valid_template + '</instance_templates></topology>'
    end

    # this is used to let the connection to be valid
    supported_elements ='<instance_templates>
      <template id="ec2_small_instance"/>
      <template id="database_container"/>
    </instance_templates>
    <container id="web_host_container"/>
    <node id="web_host"/>
    <node id="data_host"/>'
    # topology that contains an valid node definition is also valid
    get_valid_nodes.each do |valid_node|
      valid_topologies << '<topology id="valid_topology">' + supported_elements + valid_node + '</topology>'
    end

    # topology that contains an valid container definition is also valid
    get_valid_containers.each do |valid_container|
      valid_topologies << '<topology id="valid_topology">' + supported_elements + valid_container + '</topology>'
    end

    valid_topologies
  end

  protected

  def assert_differences_helper(expr, diff, proc)
    Proc.new do
      assert_difference expr, diff, &proc
    end
  end

  def tree_equals?(doc1, doc2)
    unless element_equals?(doc1, doc2)
      return false
    end

    unless get_num_of_child_elements(doc1) == get_num_of_child_elements(doc2)
      return false
    end

    doc1.each_element do |element_i|
      is_equal = false
      doc2.each_element do |element_j|
        if tree_equals?(element_i, element_j)
          is_equal = true
        end
      end

      return false unless is_equal
    end

    return true
  end

  def get_num_of_child_elements(elem)
    count = 0
    elem.each_element{|e| count += 1}
    count
  end

  def element_equals?(elem1, elem2)
    return false if elem1.name != elem2.name
    return false if get_content(elem1) != get_content(elem2)
    return false if elem1.attributes.length != elem2.attributes.length
    elem1.each_attr do |attr|
      if attr.value != elem2[attr.name]
        return false
      end
    end

    return true
  end

  def get_content(elem)
    elem.each do |child|
      return child.content.strip if child.text? && !child.content.strip.empty?
    end
  end
end