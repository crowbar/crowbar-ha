#
# 2009-2013, Opscode, Inc
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

# This is largely copied/inspired from https://github.com/hw-cookbooks/haproxy

use_inline_resources if defined?(use_inline_resources)

action :create do
  # While there is no way to have an include directive for haproxy
  # configuration file, this provider will only modify attributes !

  if !new_resource.port.zero? && new_resource.type == "backend"
    if new_resource.port < 1 || new_resource.port > 65535
      raise "Invalid port: #{new_resource.port}."
    end
  end

  if new_resource.servers.empty?
    raise "No server specified." if new_resource.type != "frontend"
  else
    new_resource.servers.each do |server|
      raise "One of the servers has no name." if server["name"].nil?
      raise "Server #{server["name"]} has no address." if server["address"].nil?
      raise "Server #{server["name"]} has no port." if server["port"].nil?
      raise "Server #{server["name"]} has invalid port." if server["port"] < 1 || server["port"] > 65535
    end
  end

  section = {}
  section["address"] = new_resource.address unless new_resource.address.empty?
  section["port"] = new_resource.port unless new_resource.port.zero?
  section["use_ssl"] = new_resource.use_ssl
  section["mode"] = if new_resource.use_ssl
    "tcp"
  else
    new_resource.mode
  end
  section["balance"] = new_resource.balance unless new_resource.balance.empty?

  section["options"] = new_resource.options || []
  if section["options"].empty? || section["options"].include?("defaults")
    section["options"].delete("defaults")
    if section["use_ssl"]
      section["options"] = [["ssl-hello-chk", "tcpka", "tcplog"], section["options"]].flatten
    elsif section["mode"] == "http"
      section["options"] = [["tcpka", "httplog", "forwardfor"], section["options"]].flatten
    end
  end
  section["acls"] = new_resource.acls || []
  section["use_backends"] = new_resource.use_backends || []
  unless new_resource.default_backend.empty?
    section["default_backend"] = new_resource.default_backend
  end
  section["servers"] = new_resource.servers unless new_resource.servers.empty?

  node["haproxy"]["sections"][new_resource.type] ||= {}
  node["haproxy"]["sections"][new_resource.type][new_resource.name] = section
end

action :delete do
  node["haproxy"]["sections"].keys.each do |type|
    node["haproxy"]["sections"][type].delete(new_resource.name)
  end
end
