#
# Cookbook Name:: corosync
# Recipe:: service
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

include_recipe "corosync::install"
include_recipe "corosync::config"
include_recipe "corosync::authkey"

case node.platform
when %w(debian ubuntu)
  template "/etc/default/corosync" do
    source "corosync.default.upstart.erb"
    owner "root"
    group "root"
    mode 0600
    variables(:enable_openais_service => node['corosync']['enable_openais_service'])
  end
end

unless node.platform == 'suse'
  # This block is not really necessary because chef would automatically backup the file.
  # However, it's good to have the backup file in the same directory. (Easier to find later.)
  ruby_block "backup corosync init script" do
    block do
        original_pathname = "/etc/init.d/corosync"
        backup_pathname = original_pathname + ".old"
        FileUtils.cp(original_pathname, backup_pathname, :preserve => true)
    end
    action :create
    notifies :create, "cookbook_file[/etc/init.d/corosync]", :immediately
    not_if "test -f /etc/init.d/corosync.old"
  end

  cookbook_file "/etc/init.d/corosync" do
    source "corosync.init"
    owner "root"
    group "root"
    mode 0755
    action :nothing
    notifies :restart, "service[corosync]", :immediately
  end
end

# This package is needed so Chef can set the user password, but
# chef-client can only use it immediately if we install it at
# recipe compile-time, not run-time:
# from the next run onwards:
pkg = package "rubygem-ruby-shadow" do
  action :nothing
end
pkg.run_action(:install) if node.platform == 'suse'

user node[:corosync][:user] do
  action :modify
  # requires ruby-shadow gem
  password node[:corosync][:password]
end

# After installation of ruby-shadow, we have a new path for the new gem, so we
# need to reset the paths if we can't load ruby-shadow
begin
  require 'shadow'
rescue LoadError
  Gem.clear_paths
end

# If this file exists, then we will require that corosync is either manually
# started or that the file gets removed to have chef-client start corosync.
#
# If the node goes down properly, then the corosync-shutdown service
# that we install will remove the file, which will allow the chef-client to
# start corosync on next boot.
#
# If the node goes down without the proper shutdown process (it has been
# fenced, or it lost power, or it crashed, or...), then the file will exist
# and corosync will not start on next boot, requiring manual intervention.
block_corosync_file = "/var/spool/corosync/block_automatic_start"
corosync_shutdown = "#{node[:corosync][:platform][:service_name]}-shutdown"

if node[:corosync][:require_clean_for_autostart]
  # We want to fail (so we do not start corosync) if these two conditions are
  # both met:
  #  a) the blocking file exists
  #  b) corosync is not running
  #
  # If a) is not true, then we had a proper shutdown/reboot and we can just
  # proceed (and start corosync)
  # If b) is not true, then corosync is already running, which either means
  # that we went through a) in an earlier chef run, or that the user manually
  # started the service (and acknowledged the issues with improper shutdown).
  if ::File.exists?(block_corosync_file) && !system("crm status &> /dev/null")
    raise "Not starting #{node[:corosync][:platform][:service_name]} automatically as " \
          "it seems the node was not properly shut down. Please manually start the " \
          "#{node[:corosync][:platform][:service_name]} service, or remove " \
          "#{block_corosync_file} and run chef-client."
  end

  # this service will remove the blocking file on proper shutdown
  template "/etc/init.d/#{corosync_shutdown}" do
    source "corosync-shutdown.init.erb"
    owner "root"
    group "root"
    mode 0755
    variables(
      :service_name => node[:corosync][:platform][:service_name],
      :block_corosync_file => block_corosync_file
    )
  end

  service corosync_shutdown do
    action :enable
  end

  # we make sure that corosync is not enabled to start on boot
  enable_or_disable = :disable
else
  # we don't need corosync-shutdown anymore
  service corosync_shutdown do
    action :disable
  end

  file "/etc/init.d/#{corosync_shutdown}" do
    action :delete
  end

  file block_corosync_file do
    action :delete
  end

  enable_or_disable = :enable
end

service node[:corosync][:platform][:service_name] do
  supports :restart => true, :status => :true
  action [enable_or_disable, :start]
end

if node[:corosync][:require_clean_for_autostart]
  # we create the file that will block starting corosync on next reboot

  directory ::File.dirname(block_corosync_file) do
    owner "root"
    group "root"
    mode "0700"
    action :create
  end

  file block_corosync_file do
    owner "root"
    group "root"
    mode "0644"
    action :create
  end
end
