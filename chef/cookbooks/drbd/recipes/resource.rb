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

# This recipe doesn't work the usual way recipe works!
#
# It is included from other recipes each time after a resource has been defined
# (in node['drbd']['rsc']). That's why we use the 'configured' attribute: it's
# a guard to make sure that we do not run the recipe for a resource that we
# already handled earlier on.

node['drbd']['rsc'].each do |resource, data|
  next if data['configured']

  if node['drbd']['rsc'][resource]['remote_host'].nil?
    Chef::Application.fatal! "You must have a ['drbd']['rsc'][resource]['remote_host'] defined to use the drbd::resource recipe."
    next
  end

  remote_nodes = search(:node, "name:#{node['drbd']['rsc'][resource]['remote_host']}")
  raise "Remote node #{node['drbd']['rsc'][resource]['remote_host']} not found!" if remote_nodes.empty?
  remote = remote_nodes.first

  template "/etc/drbd.d/#{resource}.res" do
    source "resource.erb"
    variables(
      :resource => resource,
      :device => node['drbd']['rsc'][resource]['device'],
      :disk => node['drbd']['rsc'][resource]['disk'],
      :local_hostname => node.name.split('.')[0],
      :local_ip => node.ipaddress,
      :port => node['drbd']['rsc'][resource]['port'],
      :remote_hostname => remote.name.split('.')[0],
      :remote_ip => remote.ipaddress
    )
    owner "root"
    group "root"
    action :create
  end

  # first pass only, initialize drbd 
  # for disks re-usage from old resources we will run with force option
  execute "drbdadm -- --force create-md #{resource}" do
    subscribes :run, resources(:template => "/etc/drbd.d/#{resource}.res"), :immediate
    notifies :restart, resources(:service => "drbd"), :immediate
    only_if do
      cmd = Chef::ShellOut.new("drbd-overview")
      overview = cmd.run_command
      Chef::Log.info overview.stdout
      overview.stdout.include?("Unconfigured")
    end
    action :nothing
  end

  # claim primary based off of node['drbd'][resource]['master']
  execute "drbdadm -- --overwrite-data-of-peer primary #{resource}" do
    subscribes :run, resources(:execute => "drbdadm -- --force create-md #{resource}"), :immediate
    only_if { node['drbd']['rsc'][resource]['master'] && !node['drbd']['rsc'][resource]['configured'] }
    action :nothing
  end

  # you may now create a filesystem on the device, use it as a raw block device
  # for disks re-usage from old resources we will run with force option
  execute "mkfs -t #{node['drbd']['rsc'][resource]['fs_type']} -f #{node['drbd']['rsc'][resource]['device']}" do
    subscribes :run, resources(:execute => "drbdadm -- --overwrite-data-of-peer primary #{resource}"), :immediate
    only_if { node['drbd']['rsc'][resource]['master'] && !node['drbd']['rsc'][resource]['configured'] }
    action :nothing
  end

  unless node['drbd']['rsc'][resource]['mount'].nil? or node['drbd']['rsc'][resource]['mount'].empty?
    directory node['drbd']['rsc'][resource]['mount']

    #mount -t xfs -o rw /dev/drbd0 /shared
    mount node['drbd']['rsc'][resource]['mount'] do
      device node['drbd']['rsc'][resource]['device']
      fstype node['drbd']['rsc'][resource]['fs_type']
      only_if { node['drbd']['rsc'][resource]['master'] && node['drbd']['rsc'][resource]['configured'] }
      action :mount
    end
  end

  ruby_block "Wait for DRBD resource when it will be ready" do
    block do
      begin
        cmd = Chef::ShellOut.new("drbd-overview | grep #{resource}")
        output = cmd.run_command
        sleep 1
      end while not (output.stdout.include?("Primary") && output.stdout.include?("Secondary"))
      node.normal['drbd']['rsc'][resource]['configured'] = true
      node.save
    end
  end
end
