#
# Copyright 2017, SUSE
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require "rexml/document"

module CrowbarPacemakerCIBAttribute
  def self.cib_up_for_node?
    system "crm_node -q &>/dev/null"
  end

  def self.validate_simple(string, type)
    # only accept alphanumeric characters as well as - and _
    msg = "Invalid #{type} when interacting with pacemaker attributes: #{string}"
    raise msg if string !~ /^[-\w]*$/
  end

  def self.validate_node(node)
    validate_simple(node, "node name")
  end

  def self.validate_attribute(attribute)
    validate_simple(attribute, "attribute name")
  end

  def self.validate_value(value)
    validate_simple(value, "value")
  end

  def self.get(node, attribute, default)
    # This is what we want:
    # $ crm_attribute --name=crowbar_sync-pacemaker_setup --node=d52-54-77-77-77-2 --query --default=0
    # Could not map name=d52-54-77-77-77-2 to a UUID
    # $ crm_attribute --name=crowbar_sync-pacemaker_setup --node=d52-54-77-77-77-02 --query --default=0
    # scope=nodes  name=crowbar_sync-pacemaker_setup value=0
    validate_node(node)
    validate_attribute(attribute)
    validate_value(default)

    return default unless cib_up_for_node?

    output = `crm_attribute --name=#{attribute} --node=#{node} --query --default=#{default} 2>&1`

    map_name_error = "Cannot fetch attribute for node unknown to pacemaker (#{output})"
    unexpected_output_error = "Unexpected output when fetching pacemaker attribute: #{output}"
    raise map_name_error if output =~ /^Could not map name=/
    raise unexpected_output_error if output !~ /^scope=nodes\s+name=#{attribute}\s+value=(.*)$/

    Chef::Log.debug("CrowbarPacemakerCIBAttribute.get: #{node}:#{attribute}:#{Regexp.last_match(1)}")
    Regexp.last_match(1)
  end

  def self.set(node, attribute, value)
    # We want to do something like:
    # $ crm_attribute --name=crowbar_sync-pacemaker_setup --node=d52-54-77-77-77-01 --update=1
    validate_node(node)
    validate_attribute(attribute)
    validate_value(value)
    `crm_attribute --name=#{attribute} --node=#{node} --update=#{value} &> /dev/null`
    Chef::Log.debug("CrowbarPacemakerCIBAttribute.set: #{node}:#{attribute}:#{value}")
  end

  def self.unset(node, attribute)
    # We want to do something like:
    # $ crm_attribute --name=crowbar_sync-pacemaker_setup --node=d52-54-77-77-77-01 --delete
    validate_node(node)
    validate_attribute(attribute)
    `crm_attribute --name=#{attribute} --node=#{node} --delete &> /dev/null`
  end

  def self.list(node)
    # We want to do something like:
    # $ crm_mon --show-node-attributes --as-xml
    # <?xml version="1.0"?>
    # <crm_mon version="1.1.13">
    # [...]
    #     <node_attributes>
    #         <node name="d52-54-77-77-77-01">
    #             <attribute name="OpenStack-role" value="controller" />
    #             <attribute name="crowbar_sync-pacemaker_setup" value="1" />
    #             <attribute name="maintenance" value="off" />
    #         </node>
    #         <node name="d52-54-77-77-77-02">
    #             <attribute name="OpenStack-role" value="controller" />
    #             <attribute name="maintenance" value="off" />
    #         </node>
    #         <node name="d52-54-77-77-77-03">
    #             <attribute name="OpenStack-role" value="controller" />
    #             <attribute name="maintenance" value="off" />
    #         </node>
    #     </node_attributes>
    # [...]
    validate_node(node)

    begin
      xml = REXML::Document.new(`crm_mon --show-node-attributes --as-xml 2> /dev/null`)
    rescue REXML::ParseException
      raise "Cannot parse output of crm_mon when listing attributes!"
    end

    raise "No xml output from crm_mon when listing attributes!" if xml.root.nil?

    all_attributes = {}

    xml.root.elements.each("node_attributes/node[@name=\"#{node}\"]/attribute") do |element|
      all_attributes[element.attributes["name"]] = element.attributes["value"]
    end

    all_attributes
  end
end
