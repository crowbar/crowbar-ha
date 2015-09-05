#
# Author:: Robert Choi, Ovais Tariq <me@ovaistariq.net>
# Cookbook Name:: pacemaker
# Recipe:: default
#
# Copyright 2013, Robert Choi
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

if node["pacemaker"]["platform"]["packages"].nil?
  Chef::Application.fatal! "FIXME: #{node['platform']} platform not supported yet"
end

# The crm command-line needs to be installed separately on RHEL
crmsh_package = node["pacemaker"]["platform"]["crm_package"]

# Configure the necessary yum repositories
case node["platform_family"]
when 'rhel'
  # Configure the opensuse HA/Clustering repository for CentOS 6
  yum_repository 'network_ha-clustering_Stable' do
    description "Stable High Availability/Clustering packages (CentOS_CentOS-6)"
    baseurl "http://download.opensuse.org/repositories/network:/ha-clustering:/Stable/CentOS_CentOS-6/"
    gpgkey 'http://download.opensuse.org/repositories/network:/ha-clustering:/Stable/CentOS_CentOS-6/repodata/repomd.xml.key'
    gpgcheck true
    enabled true
    action :nothing
  end

  # Install the crmsh package separately
  package crmsh_package do
    action :nothing

    # Disable the opensuse HA/Clustering repository
    notifies :delete, 'yum_repository[network_ha-clustering_Stable]', :immediately
  end
end

node["pacemaker"]["platform"]["packages"].each do |pkg|
  package pkg do
    action :install

    if node["platform_family"] == "rhel"
      notifies :create, 'yum_repository[network_ha-clustering_Stable]', :immediately
      notifies :install, "package[#{crmsh_package}]", :immediately
    end
  end
end

unless node.platform == "suse" && node.platform_version.to_f >= 12.0
  if node["pacemaker"]["setup_hb_gui"]
    node["pacemaker"]["platform"]["graphical_packages"].each do |pkg|
      package pkg
    end

    # required to run hb_gui
    if platform_family? "suse"
      cmd = "SuSEconfig --module gtk2"
      execute cmd do
        user "root"
        command cmd
        not_if { File.exists? "/etc/gtk-2.0/gdk-pixbuf64.loaders" }
      end
    end
  end
end

# Setup corosync
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
  # We need to implement the block_automatic_start logic here too to avoid
  # having on boot pacemaker started (and starting corosync) when chef is
  # supposed to handle that (see comments in corosync::service)
  if node[:corosync][:require_clean_for_autostart]
    enable_or_disable = :disable
  else
    enable_or_disable = :enable
  end
  service "pacemaker" do
    action [enable_or_disable, :start]
    retries 3
    retry_delay 30
  end
end

ruby_block "wait for cluster to be online" do
  block do
    require "timeout"
    begin
      Timeout.timeout(60) do
        cmd = "crm_mon -1 | grep -qi online"
        while ! ::Kernel.system(cmd)
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

if node["pacemaker"]["founder"]
  include_recipe "pacemaker::setup"
end

include_recipe "pacemaker::stonith"
include_recipe "pacemaker::notifications"
