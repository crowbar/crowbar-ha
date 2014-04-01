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

node['drbd']['rsc'].each do |resource_name, resource|
  next if resource['configured']

  if resource['remote_host'].nil?
    Chef::Application.fatal! "No remote host defined for drbd resource #{resource_name}!"
    next
  end

  remote_nodes = search(:node, "name:#{resource['remote_host']}")
  raise "Remote node #{resource['remote_host']} not found!" if remote_nodes.empty?
  remote = remote_nodes.first

  template "/etc/drbd.d/#{resource_name}.res" do
    source "resource.erb"
    variables(
      :resource => resource_name,
      :device => resource['device'],
      :disk => resource['disk'],
      :local_hostname => node.hostname,
      :local_ip => node.ipaddress,
      :port => resource['port'],
      :remote_hostname => remote.hostname,
      :remote_ip => remote.ipaddress
    )
    owner "root"
    group "root"
    action :create
  end

  grep_drbd_overview = "drbd-overview | grep -E \"^ *[0-9]+:#{resource_name}[/ ]\""

  # first pass only, initialize drbd 
  # for disks re-usage from old resources we will run with force option
  execute "drbdadm -- --force create-md #{resource_name}" do
    subscribes :run, resources(:template => "/etc/drbd.d/#{resource_name}.res"), :immediately
    notifies :restart, resources(:service => "drbd"), :immediately
    only_if do
      cmd = Chef::ShellOut.new(grep_drbd_overview)
      overview = cmd.run_command
      Chef::Log.info overview.stdout
      overview.stdout.include?("Unconfigured")
    end
    action :nothing
  end

  # claim primary based off of resource['master']
  execute "drbdadm -- --overwrite-data-of-peer primary #{resource_name}" do
    subscribes :run, resources(:execute => "drbdadm -- --force create-md #{resource_name}"), :immediately
    only_if { resource['master'] && !resource['configured'] }
    action :nothing
  end

  # you may now create a filesystem on the device, use it as a raw block device
  # for disks re-usage from old resources we will run with force option
  execute "mkfs -t #{resource['fs_type']} -f #{resource['device']}" do
    subscribes :run, resources(:execute => "drbdadm -- --overwrite-data-of-peer primary #{resource_name}"), :immediately
    only_if { resource['master'] && !resource['configured'] }
    action :nothing
  end

  unless resource['mount'].nil? or resource['mount'].empty?
    directory resource['mount']

    #mount -t xfs -o rw /dev/drbd0 /shared
    mount resource['mount'] do
      device resource['device']
      fstype resource['fs_type']
      only_if { resource['master'] && resource['configured'] }
      action :mount
    end
  end

  ruby_block "Wait for DRBD resource when it will be ready" do
    block do
      require 'timeout'

      begin
        Timeout.timeout(20) do
          begin
            cmd = Chef::ShellOut.new(grep_drbd_overview)
            output = cmd.run_command
            sleep 1
          end while not (output.stdout.include?("Primary") && output.stdout.include?("Secondary"))
          node.normal['drbd']['rsc'][resource_name]['configured'] = true
          node.save
        end # Timeout
      rescue Timeout::Error
        raise "DRBD resource not ready!"
      end
    end # block
  end # ruby_block
end
