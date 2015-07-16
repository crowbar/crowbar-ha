#
# 2014, SUSE
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

use_inline_resources if defined?(use_inline_resources)

action :create do
  name = new_resource.name
  fstype = new_resource.fstype
  lvm_size = new_resource.size

  raise "Missing drbd resource name!" if name.nil?
  raise "Missing fstype for drbd resource #{name}!" if fstype.nil?
  raise "Missing size for drbd resource #{name}!" if lvm_size.nil?

  remote_host = nil
  CrowbarPacemakerHelper.cluster_nodes(node).each do |cl_node|
    if cl_node[:fqdn] != node[:fqdn]
      remote_host = cl_node[:fqdn]
      break
    end
  end

  is_master = CrowbarPacemakerHelper.is_cluster_founder?(node)

  if node["drbd"]["rsc"].has_key?(name)
    resource = node["drbd"]["rsc"][name]

    dirty = false
    dirty ||= true if resource["fstype"] != fstype
    dirty ||= true if resource["remote_host"] != remote_host
    dirty ||= true if resource["master"] != is_master

    if dirty && resource["configured"]
      raise "Configuration for DRBD resource #{name} has changed. If this is really wanted, please manually set node['drbd']['rsc']['#{name}']['configured'] to false with knife; the content of the DRBD resource will be lost!"
    end

    node["drbd"]["rsc"][name]["lvm_size"] = lvm_size
    node["drbd"]["rsc"][name]["fstype"] = fstype
    node["drbd"]["rsc"][name]["remote_host"] = remote_host
    node["drbd"]["rsc"][name]["master"] = is_master
  else
    next_free_port = 7788
    next_free_device = 0

    node["drbd"]["rsc"].each do |other_resource_name, other_resource|
      next_free_port = [next_free_port, other_resource['port'] + 1].max
      device = other_resource['device'].gsub("/dev/drbd", "").to_i
      next_free_device = [next_free_device, device + 1].max
    end

    node["drbd"]["rsc"][name] = {
      "lvm_size" => lvm_size,
      "lvm_lv" => name,
      "remote_host" => remote_host,
      "port" => next_free_port,
      "device" => "/dev/drbd#{next_free_device}",
      "fstype" => fstype,
      "master" => is_master,
      "configured" => false
    }
  end
end
