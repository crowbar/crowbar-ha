#
# Cookbook Name:: corosync
# Recipe:: client
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

# chef makes csync2 redundant
if platform_family? "suse"
  service "csync2" do
    action [:stop, :disable]
  end
end

if platform_family? "rhel"
  # http://clusterlabs.org/quickstart.html
  Chef::Application.fatal! "FIXME: RedHat-based platforms configure corosync via cluster.conf"
  return
end

template "/etc/corosync/corosync.conf" do
  source "corosync.conf.erb"
  owner "root"
  group "root"
  mode 0600
  variables(
    :cluster_name => node[:corosync][:cluster_name],
    :bind_addr    => node[:corosync][:bind_addr],
    :mcast_addr   => node[:corosync][:mcast_addr],
    :mcast_port   => node[:corosync][:mcast_port]
  )

  service_name = node[:pacemaker][:platform][:service_name] rescue nil
  if service_name
    notifies :restart, "service[#{service_name}]"
  end
end
