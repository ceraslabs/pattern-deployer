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
require "xml"
require "my_errors"

class TopologyWrapper
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

  def get_topology_id
    @doc.find_first("/topology")["id"]
  end

  #def get_full_name(name)
  #  ["NestedQEMU", "topology", get_topology_id, "node", name].join("_")
  #end

  def get_nodes
    @doc.find("//node").map do |node|
      node["id"]
    end
  end

  def get_nodes_in_container(container_id)
    container_element = @doc.find_first("//container[@id='#{container_id}']")
    if container_element
      node_ids = container_element.find("//node").map do |node_element|
        node_element["id"]
      end
    else
      node_ids = Array.new
    end
    return node_ids
  end

  def get_node(node_id)
    @doc.find_first("//node[@id='#{node_id}']")
  end

  def get_container(container_id)
    @doc.find_first("//container[@id='#{container_id}']")
  end

  def get_elements_helper(base_element, template_ref_element, template_ref_attr)
    elements = Array.new
    base_element.each do |element|
      if element.name == template_ref_element
        template_id = element[template_ref_attr]
        template = @doc.find_first("//template[@id='#{template_id}']")
        elements |= get_elements_helper(template, "extend", "template")
      else
        elements << element
      end
    end
    return elements
  end

  def get_elements(node_id)
    get_elements_helper(get_node(node_id), "use_template", "name")
  end

  def get_node_info(node_id)
    node_info = Hash.new
    get_elements(node_id).each do |element|
      next if element.name == "service"  # skip service elements because it is allowed to be duplicated, so we cannot hash it from a key

      if element.content
        node_info[element.name] = element.content.strip
      else
        node_info[element.name] = true
      end
    end
    return node_info
  end

  def get_provider(node_id)
    provider = get_node_info(node_id)["cloud"]
    provider ||= Rails.application.config.notcloud
    return provider
  end

  def get_node_refs(in_element, type)
    refs = Array.new
    get_node_refs_helper.each do |ref|
      next if ref["in_element"] != in_element
      refs << { "from" => ref["from"], "to" => ref["to"], "type" => type }
    end

    refs
  end

  def get_node_refs_helper
    node_refs = Array.new
    @doc.find("//node | //template").each do |from_element|
      case from_element.name
      when "template"
        template_id = from_element["id"]
        from_nodes_ids = get_nodes_with_template(template_id).map{ |node| node["id"] }
      when "node"
        from_nodes_ids = [from_element["id"]]
      else
        raise "Unexpected element name #{from_element.name}"
      end

      from_element.find(".//*[@node]").each do |ref_element|
        from_nodes_ids.each do |from_node_id|
          from_nodes = get_all_copies(from_node_id)
          to_node_id = ref_element["node"]
          to_nodes = get_all_copies(to_node_id)

          if from_nodes.size == 1 && to_nodes.size == 1
            node_refs << { "from" => from_nodes.first, "to" => to_nodes.first, "in_element" => ref_element.name.to_s }
          elsif from_nodes.size > 1 && to_nodes.size == 1
            from_nodes.each do |from_node|
              node_refs << { "from" => from_node, "to" => to_nodes.first, "in_element" => ref_element.name.to_s }
            end
          elsif from_nodes.size == 1 && to_nodes.size > 1
            to_nodes.each do |to_node|
              node_refs << { "from" => from_nodes.first, "to" => to_node, "in_element" => ref_element.name.to_s }
            end
          elsif from_nodes.size == to_nodes.size
            for i in 0 .. from_nodes.size - 1
              node_refs << { "from" => from_nodes[i], "to" => to_nodes[i], "in_element" => ref_element.name.to_s }
            end
          else
            err_msg = "The dependencies from node '#{from_node_id}' to node '#{to_node_id}' is invalid. "
            err_msg += "For valid dependencies, the depending node and the depended node must have same number of copies or at least one of them has just one copy"
            raise XmlValidationError.new(:message => err_msg)
          end
        end
      end
    end

    node_refs
  end

  def get_dependencies
    get_nested_node_refs
  end

  def get_nested_node_refs
    in_element = "nest_within"
    type       = "nest"
    get_node_refs(in_element, type)
  end

  def get_openvpn_client_server_refs
    in_element = "openvpn_server"
    type       = "openvpn"
    get_node_refs(in_element, type)
  end

  def get_webserver_database_refs
    in_element = "database_connection"
    type       = "webserver-database"
    get_node_refs(in_element, type)
  end

  def get_load_balancer_memeber_refs
    in_element = "member"
    type       = "load_balancing"
    get_node_refs(in_element, type)
  end

  def get_chef_server_refs
    in_element = "chef_server"
    type       = "chef_client_server"
    get_node_refs(in_element, type)
  end

  def get_minotor_client_server_refs
    in_element = "monitor"
    type       = "monitor_client"
    get_node_refs(in_element, type)
  end

  def get_minotor_server_client_refs
    in_element = "send_metric_to"
    type       = "monitor_server"
    get_node_refs(in_element, type)
  end

  def generate_ip(used_ips)
    ip = nil
    begin
      first = rand(32) + 192 # The address must in class C (192.0.0.0 -> 223.255.255.255)
      second = rand(256)
      third = rand(256)
      ip = "#{first}.#{second}.#{third}.1"
    end while used_ips.include?(ip)
    return ip
  end

  # TODO simplify this
  def get_vpnips()
    used_ips = @doc.find("//vpnip").map do |vpnip|
      ip = vpnip.content.strip
      unless ip.end_with?(".1")
        raise "Invalid vpnip: vpnip must end with '.1'" 
      end
      ip
    end

    vpnips = Hash.new
    @doc.find(".//service[@name='openvpn_server']").each do |openvpn_server|
      node = openvpn_server.parent

      indice_with_ip = []
      free_ips = Queue.new
      node.find(".//vpnip").each do |vpnip_element|
        if vpnip_element["index"].nil?
          free_ips << vpnip_element.content.strip
        else
          node_name = "#{node['id']}_#{vpnip_element['index']}"
          vpnips[node_name] = vpnip_element.content.strip
          indice_with_ip << Integer(vpnip_element["index"])
        end
      end

      all_indice = Array(1 .. get_num_of_copies(node["id"]))
      indice_without_ip = all_indice - indice_with_ip

      indice_without_ip.each do |i|
        node_name = node['id'] + "_" + i.to_s
        if free_ips.empty?
          generated_ip = generate_ip(used_ips)
          used_ips << generated_ip
          vpnips[node_name] = generated_ip
        else
          vpnips[node_name] = free_ips.pop
        end
      end
    end

    return vpnips
  end

  def get_war_files
    file_infos = Hash.new
    get_nodes.each do |node_id|
      get_service_elements(node_id).each do |service_element|
        file_element = service_element.find_first("war_file")
        next unless file_element

        file_info = {"name" => file_element.find_first("file_name").content.strip}
        file_element.each_element do |element|
          (file_info[element.name] ||=  Array.new) << element.content.strip
        end

        get_all_copies(node_id).each do |node_copy|
          file_infos[node_copy] = file_info
        end
      end
    end

    file_infos
  end

  def get_databases
    infos = Hash.new
    get_nodes.each do |node_id| 
      get_service_elements(node_id).each do |service_element|
        next if service_element["name"] != "database_server"

        db_info = Hash.new
        service_element.each_element do |element|
          key = element.name.sub(/^database_/, "")
          db_info[key] = element.content.strip
        end
        db_info["system"]   ||= "mysql"
        db_info["name"]     ||= "mydb"
        db_info["user"]     ||= "myuser"
        db_info["password"] ||= "mypass"

        db_info["system"] = db_info["system"].downcase if db_info["system"]

        case db_info["system"]
        when "mysql"
          db_info["port"] ||= "3306"
        when "postgresql"
          db_info["port"] ||= "5432"
        else
          raise ParametersValidationError.new(:message => "Unexpected dbms #{db_info['system']}, only 'mysql' or 'postgresql' is allowed")
        end

        get_all_copies(node_id).each do |node_copy|
          infos[node_copy] = db_info
        end
      end
    end

    infos
  end

  def get_service_elements(node_id)
    get_elements(node_id).select do |element|
      element.name == "service"
    end
  end

  def get_services(node_id)
    services = Array.new
    get_service_elements(node_id).each do |element|
      service_name = element["name"]
      if service_name == "openvpn_client" || service_name == "openvpn_server"
        services.unshift(service_name) #TODO check if unshift is needed
      else
        services << service_name
      end
    end

    services
  end

  def get_port_redirs
    redirs = Hash.new
    get_nodes.each do |node_id|
      node_redirs = Array.new
      get_service_elements(node_id).each do |service_element|
        service_element.find("port_redirection").each do |redir|
          node_redirs << redir["protocol"] + ":" + redir["from"] + "::" + redir["to"]
        end
      end
      
      next if node_redirs.empty?

      node_redirs << "tcp:5555::22" 
      get_all_copies(node_id).each do |node_copy|
        redirs[node_copy] = node_redirs
      end
    end
    return redirs
  end

  def get_snort_pairs
    @doc.find(".//snort_pair_first").map do |first_element|
      first_node_id  = first_element["node"]
      second_element = first_element.next
      second_node_id = second_element["node"]
      snort_element  = first_element.parent.parent
      snort_node_id  = snort_element["node"]

      return { "snort_node" => snort_node_id, "pair1" => first_node_id, "pair2" => second_node_id }
    end
  end

  def get_nodes_with_services(services)
    nodes = Array.new
    @doc.find("//node").each do |node_element|
      node_id = node_element["id"]
      node_services = get_services(node_id)
      if (node_services & services).length > 0
        nodes |= get_all_copies(node_id)
      end
    end

    return nodes
  end

  def get_openvpn_clients
    return get_nodes_with_services(["openvpn_client"])
  end

  def get_load_balancers
    return get_nodes_with_services(["web_balancer", "front_end_balancer"])
  end

  def get_dns_clients
    get_nodes_with_services(["dns_client"])
  end

  def get_hids_clients
    get_nodes_with_services(["ossec_client"])
  end

  def get_nodes_with_template(template_id)
    nodes = Hash.new
    get_descendant_templates(template_id).each do |d_template|
      @doc.find("//use_template[@name='#{d_template}']").each do |use_template_element|
        node = use_template_element.parent
        node_id = node["id"]
        nodes[node_id] = node unless nodes.has_key?(node_id)
      end
    end

    nodes.values
  end

  def get_descendant_templates(source_template)
    # use breadth first search algorithm
    descendants = Array.new
    descendants << source_template
    queue = Queue.new
    queue << source_template
    while queue.size > 0
      template = queue.pop
      get_child_templates(template).each do |child|
        next if descendants.include?(child)
        descendants << child
        queue << child
      end
    end

    descendants
  end

  def get_child_templates(template_id)
    templates = Array.new
    @doc.find("//extend[@template='#{template_id}']").each do |extend_element|
      parent_template = extend_element.parent["id"]
      templates << parent_template unless templates.include?(parent_template)
    end
    templates
  end

  def get_num_of_copies(id)
    element = get_node(id)
    #element = get_container(id) if element.nil?
    raise "Failed to find any node with id: #{id}" unless element
    
    num_of_copies = 1
    if element.parent.name == "container"
      num_of_copies = Integer(element.parent["num_of_copies"] || "1")
    end
    return num_of_copies
  end

  def get_all_copies(node_id)
    num_of_copies = get_num_of_copies(node_id)
    all_copies = Array.new
    for i in 1..num_of_copies
      all_copies << "#{node_id}_#{i}"
    end
    return all_copies
  end

  #def add_node(node_element, container_id)
  #  container_element = @doc.find_first("//container[@id='#{container_id}']")
  #  container_element << node_element.copy
  #end

  #def save(path_to_file)
  #  file = File.open(path_to_file, "w")
  #  file.sync = true
  #  @doc.write(file, 2)
  #end

  #def reload(topology_file)
  #  xml = File.read(topology_file)
  #  @doc = REXML::Document.new(xml)
  #end
  
  #def overwrite_node(new_node_element)
  #  node_id = new_node_element["id"]
  #  old_node_element = @doc.find_first("//node[@id='#{node_id}']")
  #  if old_node_element
  #    container_element = old_node_element.parent
  #    old_node_element.remove!
  #    container_element << new_node_element.copy
  #  end
  #end

  #def create_node(node_id, elements)
  #  new_node = XML::Node.new("node")
  #  new_node["id"] = node_id
  #  elements.each do |element|
  #    new_node << element.copy
  #  end
  #  return new_node
  #end
  
  #def delete_node(node_id)
  #  node_element = get_node(node_id)
  #  if node_element
  #    node_element.remove!
  #  end
  #end

  #def dup_ref(ref_element, node_ref_to)
  #  parent = ref_element.parent
  #  if ref_element.name == "snort_pair_first" || ref_element.name == "snort_pair_second"
  #    if ref_element.name == "snort_pair_first"
  #      snort_pair_second = ref_element.next
  #      parent << snort_pair_second
  #    else
  #      snort_pair_first = ref_element.prev
  #      parent << snort_pair_first
  #    end
  #  end

  #  new_ref = XML::Node.new(ref_template.name)
  #  new_ref["node"] = node_ref_to
  #  parent << new_ref
  #end

  #def get_nodes_ref_to(my_node_id)
  #  nodes = Array.new
  #  @doc.find("//node").each do |node_element|
  #    element = node_element.find_first(".//*[@node='#{my_node_id}']")
  #    nodes << node_element if element
  #  end
  #  return nodes
  #end
  
  #def get_refs(node_element, ref_to)
  #  node_element.find(".//*[@node='#{ref_to}']")
  #end
  
  #def delete_ref(ref_element)
  #  if ref_element.name == "first" || ref_element.name == "second"
  #    # delete snort pair
  #    snort_pair = ref_element.parent
  #    container_element = snort_pair.parent
  #    container_element.delete(snort_pair)
  #  else
  #    container_element = ref_element.parent
  #    ref_element.remove!
  #  end
  #end
  
  #def generate_node_id(base_id)
  #  i = 1
  #  id = "#{base_id}_clone#{i}"
  #  while !get_node(id).nil?
  #    i = i + 1
  #    id = "#{base_id}_clone#{i}"
  #  end
  #  return id
  #end
  
  #def unify_vpnip()
  #  used_ips = Array.new
  #  @doc.find("//vpnip").each do |vpnip_element|
  #    ip = vpnip_element.content.strip
  #    raise "Invalid vpnip: vpnip must end with '.1'" unless ip.to_s.end_with?(".1")
  #    if used_ips.include?(ip)
  #      vpnip_element.parent.delete(vpnip_element)
  #    end

  #    used_ips << ip
  #  end
  #end
end