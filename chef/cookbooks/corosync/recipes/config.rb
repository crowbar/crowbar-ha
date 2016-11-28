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
if node[:platform_family] == "suse"
  service "csync2" do
    action [:stop, :disable]
  end
end

if node[:platform_family] == "rhel"
  # http://clusterlabs.org/quickstart.html
  Chef::Application.fatal! "FIXME: RedHat-based platforms configure corosync via cluster.conf"
  return
end

unless %(udp udpu).include?(node[:corosync][:transport])
  raise "Invalid transport #{node[:corosync][:transport]}!"
end

if node[:corosync][:transport] == "udpu" && (node[:corosync][:members].nil? || node[:corosync][:members].empty?)
  raise "Members have to be defined when using \"udpu\" transport!"
end

template "/etc/corosync/corosync.conf" do
  if node[:platform] == "suse" && node[:platform_version].to_f < 12.0
    source "corosync.conf.erb"
  else
    source "corosync.conf.v2.erb"
  end
  owner "root"
  group "root"
  mode 0600
  variables(
    cluster_name: node[:corosync][:cluster_name],
    bind_addr: node[:corosync][:bind_addr],
    mcast_addr: node[:corosync][:mcast_addr],
    mcast_port: node[:corosync][:mcast_port],
    members: node[:corosync][:members],
    transport: node[:corosync][:transport]
  )

  # If the config parameters are changed, it's too risky to just
  # restart the cluster - this could happen on all cluster nodes at a
  # similar time and cause a significant outage.  Fortunately it's
  # possible to instead reload the config whilst keeping corosync running,
  # via corosync-cfgtool -R.
end

execute "reload corosync.conf" do
  # corosync-cfgtool -R reloads the configuration across ALL the nodes in the
  # cluster - each reloading its own local configuration file. This means that
  # running this command on a cluster with n nodes results in n^2 reloads.
  # Given that the reloads might happen while some of the nodes still having
  # the old configuration, this approach is not valid for updating nodelist
  # or votequorum parameters, but should work for amending token timeouts.
  # Ideally we would synchronize between all nodes after the config files are
  # updated, and then just run the reload on a single node, but we can only
  # achieve that when the proposal is being applied, and we need something
  # which works with the convergence runs.
  command "corosync-cfgtool -R"
  user "root"
  group "root"
  action :nothing
  subscribes :run, "template[/etc/corosync/corosync.conf]", :delayed
end
