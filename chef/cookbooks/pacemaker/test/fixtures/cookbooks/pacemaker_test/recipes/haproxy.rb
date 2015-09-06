#
# Author:: Ovais Tariq <me@ovaistariq.net>
# Cookbook Name:: pacemaker_test
# Recipe:: haproxy
#
# Copyright 2015, Ovais Tariq
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

# Do base setup common to all the machines
include_recipe "haproxy::default"

# HAProxy configuration begins here
include_recipe "haproxy::install_#{node['haproxy']['install_method']}"

cookbook_file "/etc/default/haproxy" do
  source "haproxy-default"
  cookbook "haproxy"
  owner "root"
  group "root"
  mode 00644
  notifies :restart, "service[haproxy]"
end


if node['haproxy']['enable_admin']
  admin = node['haproxy']['admin']
  haproxy_lb "admin" do
    bind "0.0.0.0:22002"
    mode 'http'
    params(admin['options'])
  end
end

conf = node['haproxy']
member_max_conn = conf['member_max_connections']
member_weight = conf['member_weight']

haproxy_lb "pacemaker_test_lb" do
  type "listen"
  servers ["node1 127.0.0.1:8080 check inter 10s rise 2 fall 3"]
  balance "roundrobin"
  bind "0.0.0.0:80"
  mode "http"
end


# Re-default user/group to account for role/recipe overrides
node.default['haproxy']['stats_socket_user'] = node['haproxy']['user']
node.default['haproxy']['stats_socket_group'] = node['haproxy']['group']

unless node['haproxy']['global_options'].is_a?(Hash)
  Chef::Log.error("Global options needs to be a Hash of the format: { 'option' => 'value' }. Please set node['haproxy']['global_options'] accordingly.")
end

template "#{node['haproxy']['conf_dir']}/haproxy.cfg" do
  source "haproxy.cfg.erb"
  cookbook "haproxy"
  owner "root"
  group "root"
  mode 00644
  notifies :reload, "service[haproxy]"
  variables(
    :defaults_options => node["haproxy"]["defaults_options"],
    :defaults_timeouts => node["haproxy"]["defaults_timeouts"]
  )
end

service "haproxy" do
  supports :restart => true, :status => true, :reload => true
  action :nothing
end


# Make pacemaker-corosync configuration for haproxy
# Setup the haproxy privimite on the founder pacemaker node
haproxy_resource = node["pacemaker_test"]["haproxy"]["resource_name"]
vip_resource_name = node["pacemaker_test"]["virtual_ip"]["resource_name"]

pacemaker_primitive haproxy_resource do
  agent node["pacemaker_test"]["haproxy"]["agent"]
  op node["pacemaker_test"]["haproxy"]["op"]
  action :create
  only_if { node[:pacemaker][:founder] }
end

# We colocate cluster_vip and haproxy resources so that both the resources
# are started on the same node, otherwise Pacemaker will balance the different
# resources between different nodes
pacemaker_colocation "#{haproxy_resource}-#{vip_resource_name}" do
  resources "#{haproxy_resource} #{vip_resource_name}"
  score "INFINITY"
  only_if { node[:pacemaker][:founder] }
end

# We configure the order of resources so that any action taken on the resources
# cluster_vip and haproxy are taken in order
pacemaker_order "#{haproxy_resource}-after-#{vip_resource_name}" do
  ordering "#{vip_resource_name} #{haproxy_resource}"
  score "mandatory"
  only_if { node[:pacemaker][:founder] }
end
