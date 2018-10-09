#
# Author:: Robert Choi
# Cookbook Name:: pacemaker
# Recipe:: default
#
# Copyright 2013, Robert Choi
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

if node[:pacemaker][:platform][:packages].nil?
  Chef::Application.fatal! "FIXME: #{node.platform} platform not supported yet"
end

node[:pacemaker][:platform][:packages].each do |pkg|
  package pkg
end

file "/etc/sysconfig/pacemaker" do
  content "SYSTEMD_NO_WRAP=1"
  owner "root"
  mode "0644"
  action :create
end

if Chef::Config[:solo]
  unless ENV["RSPEC_RUNNING"]
    Chef::Application.fatal! \
      "pacemaker::default needs corosync::default which uses search, " \
      "but Chef Solo does not support search."
    return
  end
else
  include_recipe "corosync::default"
end

if (platform_family?("suse") && node.platform_version.to_f >= 12.0) || platform_family?("rhel")
  service "pacemaker" do
    action [:enable, :start]
    if platform_family? "rhel"
      notifies :restart, "service[clvm]", :immediately
    end
  end
end

cluster_size = node[:pacemaker][:elements]["pacemaker-cluster-member"].length
nodes_names = node[:pacemaker][:elements]["pacemaker-cluster-member"].map do |n|
  n.gsub(/\..*/, "")
end

# When newly added node is faster than the old nodes, it can finish the default timeout
# here and continue chef-client run before the cluster is fully (re)configured.
# If it reaches any syncmark it can get: "Could not map name=<nodename> to a UUID" error.
# Waiting a bit more gives the rest of the cluster some time to recognize the new member.
# Extending this timeout unconditionally would cause a deadlock with the "Waiting for
# cluster founder to be set up" loop in crowbar-pacemaker cookbook.
online_timeout = node.fetch("crowbar_wall", {})[:cluster_node_added] ? 120 : 60

ruby_block "wait for cluster to be online" do
  block do
    require "timeout"
    begin
      Timeout.timeout(online_timeout) do
        loop do
          # example of 'crm_node -l' output:
          # 1084813649 d52-54-77-77-01-02 member
          # 1084813652 d52-54-77-77-01-01 member
          crm_node_cmd = Mixlib::ShellOut.new("crm_node -l").run_command
          if crm_node_cmd.exitstatus != 0
            Chef::Log.warn("Problems when executing 'crm_node -l': #{crm_node_cmd.stderr}")
            next
          end
          crm_nodes = crm_node_cmd.stdout
          crm_names = crm_nodes.split("\n").map { |l| l.split(" ")[1] }
          crm_mon_cmd = Mixlib::ShellOut.new("crm_mon -1").run_command
          if crm_mon_cmd.exitstatus != 0
            Chef::Log.warn("Problems when executing 'crm_mon -1': #{crm_mon_cmd.stderr}")
            next
          end
          crm_mon = crm_mon_cmd.stdout
          break if crm_mon.include?("#{cluster_size} nodes configured") &&
              crm_mon.include?("Online:") &&
              crm_names.sort == nodes_names.sort
          Chef::Log.debug("cluster not online yet")
          sleep(5)
        end
      end
    rescue Timeout::Error
      message = "Pacemaker cluster not online yet; our first configuration changes might get lost (but will be reapplied on next chef run)."
      Chef::Log.warn(message)
    end
  end # block
end # ruby_block

if node[:pacemaker][:founder]
  include_recipe "pacemaker::setup"
end

include_recipe "pacemaker::stonith"
include_recipe "pacemaker::notifications"
