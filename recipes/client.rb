#
# Cookbook Name:: corosync
# Recipe:: default
#
# Copyright 2012, Rackspace US, Inc.
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

require 'base64'

# from https://github.com/mattray/barclamp_ha_service/blob/pacemaker_service/chef/cookbooks/pacemaker/recipes/master.rb

# install the corosync package
package "corosync" do
  action :upgrade
end

authkey = ""

# Find the master node:
if !File.exists?("/etc/corosync/authkey")
  if Chef::Config[:solo]
    Chef::Application.fatal! "This recipe uses search. Chef Solo does not support search."
  else
    if (node.run_list.include? "recipe[corosync::master]")
      Chef::Log.info("I am the corosync::master so I will use my auth key")
    else
      master = search(:node, "chef_environment:#{node.chef_environment} AND corosync:authkey")
      if master.length == 0
        Chef::Application.fatal! "You must have one node with the corosync::master recipe in their run list to be a client."
      elsif master.length == 1
        Chef::Log.info "Found corosync::master node: #{master[0].name}"
        authkey = Base64.decode64(master[0]['corosync']['authkey'])
      elsif master.length >1
        Chef::Application.fatal! "You have specified more than one corosync master node and this is not a valid configuration."
      end
    end
  end
end

file "/etc/corosync/authkey" do
  not_if {File.exists?("/etc/corosync/authkey")}
  content authkey
  owner "root"
  mode "0400"
  action :create
end

# TODO(breu): need the bindnetaddr for this node.
#             replace 192.168.0.0 below
# bindnetaddr = node.ipaddress[0..node.ipaddress.rindex('.')]+'0'

bindnetaddr = node['osops_networks']['management'].sub! /\/[0-9]+$/,''

template "/etc/corosync/corosync.conf" do
  source "corosync.conf.erb"
  owner "root"
  group "root"
  mode 0600
  variables(:bindnetaddr => bindnetaddr)
  notifies :restart, "service[corosync]", :delayed
end

template "/etc/default/corosync" do
  source "corosync.default.upstart.erb"
  owner "root"
  group "root"
  mode 0600
  notifies :restart, "service[corosync]", :immediately
end

service "corosync" do
  supports :restart => true, :status => :true
  action [:enable, :start]
  subscribes :restart, resources(:template => "/etc/corosync/corosync.conf"), :immediately
end

