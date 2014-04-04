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
require 'pattern_deployer/cloud'
require 'pattern_deployer/errors'
require 'pattern_deployer/utils'
require 'pattern_deployer/pattern/connection'
require 'pattern_deployer/pattern/config'
require 'pattern_deployer/pattern/database_config'
require 'pattern_deployer/pattern/reference'
require 'pattern_deployer/pattern/web_server_config'
require 'xml'

module PatternDeployer
  module Pattern
    class Pattern
      include PatternDeployer::Cloud
      include PatternDeployer::Errors
      include PatternDeployer::Utils
      include PatternDeployer::Utils::Xml

      def initialize(topology_xml)
        @doc = self.class.validate_xml(topology_xml, Rails.application.config.schema_file)
      end

      def self.validate_xml(xml, schema_file)
        schema_document = XML::Document.file(schema_file)
        schema = XML::Schema.document(schema_document)
        doc = XML::Document.string(xml)
        doc.validate_schema(schema)
        doc
      end

      def get_nodes
        @doc.find("//node").map do |node|
          node["id"]
        end
      end

      def get_node_info(node)
        node_info = Hash.new
        child_elements_of_node(node).each do |child_element|
          next if child_element.name == "service"  # skip service elements because it is allowed to be duplicated

          if hash_format?(child_element)
            node_info.merge!(xml_element_to_hash(child_element))
          else
            msg = "Invalid element '#{child_element.name}': it is not in hash format"
            raise XmlValidationError.new(:message => msg)
          end
        end

        validate_node_info(node_info)
        node_info
      end

      def get_database_connections
        get_connections(ReferenceType::DB_CONNECTION)
      end

      def get_balancer_memeber_connections
        get_connections(ReferenceType::LB_MEMBER)
      end

      def get_chef_server_connections
        get_connections(ReferenceType::CHEF_SERVER)
      end

      def get_mon_server_connections
        get_connections(ReferenceType::MON_SERVER)
      end

      def get_web_server_configs(node)
        get_service_elements(node).each do |service_element|
          # assume at most one web server per node
          if web_server?(service_element)
            return WebServerConfig.get(service_element)
          end
        end
        nil
      end

      def get_database_configs(node)
        get_service_elements(node).each do |service_element|
          # assume at most one database server per node
          if database_server?(service_element)
            return DatabaseConfig.get(service_element)
          end
        end
        nil
      end

      def get_services(node)
        get_service_elements(node).map do |service_element|
          service_element["name"]
        end
      end

      def get_num_of_copies(node)
        num_of_copies = 1
        node_element = get_node_element(node)
        parent_element = node_element.parent
        if parent_element.name == "container" && parent_element["num_of_copies"]
          begin
            num_of_copies = Integer(parent_element["num_of_copies"])
          rescue ArgumentError
            msg = "Invalid value for 'num_of_copies' attribute: it is not a number"
            raise InternalServerError.new(:message => msg)
          end
        end
        num_of_copies
      end

      def get_all_copies(node)
        num_of_copies = get_num_of_copies(node)
        all_copies = Array.new
        for i in 1..num_of_copies
          all_copies << self.class.join(node, i)
        end
        all_copies
      end

      protected

      def child_elements_of_node(node)
        node_element = get_node_element(node)
        child_elements_of_node_or_template(node_element)
      end

      def child_elements_of_node_or_template(element)
        child_elements = Array.new
        element.each_element do |child_element|
          if reference?(child_element)
            reference = Reference.new(child_element)
            if reference.refer_to_template?
              template = reference.refer_to
              template_element = get_template_element(template)
              child_elements |= child_elements_of_node_or_template(template_element)
            end
          else
            child_elements << child_element
          end
        end
        child_elements
      end

      def get_connections(reference_type)
        connections = Array.new
        all_references(reference_type).each do |ref|
          connections += reference_to_connections(ref)
        end
        connections
      end

      def reference_to_connections(reference)
        unless (reference.refer_from_node? || reference.refer_from_template?) &&
               reference.refer_to_node?
          msg = "The reference #{reference} cannot be converted to connection"
          raise InternalServerError.new(:message => msg)
        end

        if reference.refer_from_template?
          template = reference.refer_from
          source_nodes = get_nodes_using_template(template)
        elsif reference.refer_from_node?
          node = reference.refer_from
          source_nodes = [node]
        end

        connections = Array.new
        sink_node = reference.refer_to
        source_nodes.each do |source_node|
          connections += all_connections(source_node, sink_node, reference.type)
        end
        connections
      end

      def get_nodes_using_template(the_template)
        nodes = Array.new
        templates = get_extended_templates(the_template)
        all_references(ReferenceType::USE_TEMPLATE).each do |reference|
          node = reference.refer_from
          template = reference.refer_to
          if templates.include?(template) && !nodes.include?(node)
            nodes << node
          end
        end

        nodes
      end

      def all_connections(source_node, sink_node, type)
        connections = Array.new
        source_nodes = get_all_copies(source_node)
        sink_nodes = get_all_copies(sink_node)

        if source_nodes.size == 1 && sink_nodes.size == 1
          connections << Connection.create(source_nodes.first, sink_nodes.first, type)
        elsif source_nodes.size > 1 && sink_nodes.size == 1
          source_nodes.each do |source|
            connections << Connection.create(source, sink_nodes.first, type)
          end
        elsif source_nodes.size == 1 && sink_nodes.size > 1
          sink_nodes.each do |sink|
            connections << Connection.create(source_nodes.first, sink, type)
          end
        elsif source_nodes.size == sink_nodes.size
          for i in 0 .. source_nodes.size - 1
            connections << Connection.create(source_nodes[i], sink_nodes[i], type)
          end
        else
          msg = "The dependencies from node '#{source_node}' to node '#{sink_node}' is invalid. "
          msg += "For valid dependencies, the depending node and the depended node must have same number of copies "
          msg += "or at least one of them has just one copy"
          raise XmlValidationError.new(:message => msg)
        end
        connections
      end

      def get_extended_templates(source_template)
        # use breadth first search algorithm
        templates = Array.new
        templates << source_template
        queue = Queue.new
        queue << source_template
        while queue.size > 0
          template = queue.pop
          direct_extended_templates(template).each do |template|
            next if templates.include?(template)

            templates << template
            queue << template
          end
        end

        templates
      end

      def direct_extended_templates(template)
        templates = Array.new
        all_references(ReferenceType::EXTEND_TEMPLATE).each do |reference|
          if reference.refer_to == template
            extended_template = reference.refer_from
            templates << extended_template unless templates.include?(extended_template)
          end
        end
        templates
      end

      def get_node_element(node)
        node_element = @doc.find_first("//node[@id='#{node}']")
        if node_element
          node_element
        else
          msg = "The node '#{node}' does not exist"
          raise InternalServerError.new(:message => msg)
        end
      end

      def get_container_element(container)
        container_element = @doc.find_first("//container[@id='#{container}']")
        if container_element
          container_element
        else
          msg = "The node '#{container}' does not exist"
          raise InternalServerError.new(:message => msg)
        end
      end

      def get_template_element(template)
        template_element = @doc.find_first("//template[@id='#{template}']")
        if template_element
          template_element
        else
          msg = "The node '#{template}' does not exist"
          raise InternalServerError.new(:message => msg)
        end
      end

      def get_service_elements(node)
        child_elements_of_node(node).select do |element|
          service_element?(element)
        end
      end

      def node_element?(element)
        element.name == "node"
      end

      def template_element?(element)
        element.name == "template"
      end

      def service_element?(element)
        element.name == "service"
      end

      def all_references(type)
        Reference.all_references(type, @doc)
      end

      def reference?(element)
        Reference.reference?(element)
      end

      def web_server?(element)
        element["name"] == "web_server"
      end

      def database_server?(element)
        element["name"] == "database_server"
      end

      def validate_node_info(node_info)
        self.class.validate_cloud!(node_info["cloud"])
      end

    end
  end
end