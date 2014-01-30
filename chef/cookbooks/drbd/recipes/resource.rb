#
# Author:: Matt Ray <matt@opscode.com>
# Cookbook Name:: drbd
# Recipe:: resource
#
# Copyright 2011, Opscode, Inc
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

require 'chef/shell_out'

resource = node['drbd']['resource']

if node['drbd']['remote_host'].nil?
  Chef::Application.fatal! "You must have a ['drbd']['remote_host'] defined to use the drbd::resource recipe."
end

remote = search(:node, "name:#{node['drbd']['remote_host']}")[0]

template "/etc/drbd.d/#{resource}.res" do
  source "resource.erb"
  variables(
    :resource => resource,
    :remote_ip => remote.ipaddress
    )
  owner "root"
  group "root"
  action :create
end

#first pass only, initialize drbd 
#for disks re-usage from old resources we will run with force option
execute "drbdadm -- --force create-md #{resource}" do
  subscribes :run, resources(:template => "/etc/drbd.d/#{resource}.res")
  notifies :restart, resources(:service => "drbd"), :immediate
  only_if do
    cmd = Chef::ShellOut.new("drbd-overview")
    overview = cmd.run_command
    Chef::Log.info overview.stdout
    overview.stdout.include?("drbd not loaded")
  end
  action :nothing
end

#claim primary based off of node['drbd']['master']
execute "drbdadm -- --overwrite-data-of-peer primary #{resource}" do
  subscribes :run, resources(:execute => "drbdadm -- --force create-md #{resource}")
  only_if { node['drbd']['master'] && !node['drbd']['configured'] }
  action :nothing
end

#you may now create a filesystem on the device, use it as a raw block device
#for disks re-usage from old resources we will run with force option
execute "mkfs -t #{node['drbd']['fs_type']} -f #{node['drbd']['dev']}" do
  subscribes :run, resources(:execute => "drbdadm -- --overwrite-data-of-peer primary #{resource}")
  only_if { node['drbd']['master'] && !node['drbd']['configured'] }
  action :nothing
end

directory node['drbd']['mount'] do
  only_if { node['drbd']['master'] && !node['drbd']['configured'] }
  action :create
end

#mount -t xfs -o rw /dev/drbd0 /shared
mount node['drbd']['mount'] do
  device node['drbd']['dev']
  fstype node['drbd']['fs_type']
  only_if { node['drbd']['master'] && node['drbd']['configured'] }
  action :mount
end

#hack to get around the mount failing
ruby_block "set drbd configured flag" do
  block do
    node.normal['drbd']['configured'] = true
    node.save
  end
  subscribes :create, resources(:execute => "mkfs -t #{node['drbd']['fs_type']} -f #{node['drbd']['dev']}")
  action :nothing
end
