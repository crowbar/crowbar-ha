#
# Cookbook Name:: crowbar-pacemaker
# Recipe:: apache
#
# Copyright 2014, SUSE
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

# Define pacemaker primitive for apache service


# This is required for the OCF resource agent
include_recipe "apache2::mod_status"

apache_op = {}
apache_op["monitor"] = {}
apache_op["monitor"]["interval"] = "10s"

# :listen_ports_crowbar looks like { "ceph" => { :plain => [ 8080 ] }, "nova" => { :plain => [ 80 ], :ssl => [ 443 ]}}
# We need to pick any one from non-ssl ports the server is already listening to
crowbar_defined_ports   = node[:apache][:listen_ports_crowbar] || {}

listening_port = 80
unless crowbar_defined_ports.empty?
  plain_ports = crowbar_defined_ports.values.sort_by{ |k| k[:plain] || [65536] }.first[:plain]
  listening_port = plain_ports.first unless (plain_ports.nil? || plain_ports.empty?)
end

service_name = "apache2"
agent_name = node[:pacemaker][service_name][:agent]

apache_params = {}
unless agent_name == 'systemd:apache2'
  apache_params["statusurl"] = "http://127.0.0.1:#{listening_port}/server-status"
end
unless crowbar_defined_ports.values.select{|service| service.has_key? :ssl}.empty?
  apache_params["options"] = "-DSSL"
end

pacemaker_primitive service_name do
  agent agent_name
  params apache_params
  op    apache_op
  action :create
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

pacemaker_clone "cl-#{service_name}" do
  rsc service_name
  action [ :create, :start ]
  only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
end

# Override service provider for apache2 resource defined in apache2 cookbook
resource = resources(:service => "apache2")
resource.provider(Chef::Provider::CrowbarPacemakerService)
