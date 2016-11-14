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

case node[:platform_family]
when "debian"
  template "/etc/default/corosync" do
    source "corosync.default.upstart.erb"
    owner "root"
    group "root"
    mode 0600
    variables(enable_openais_service: node["corosync"]["enable_openais_service"])
  end
end

unless node[:platform_family] == "suse"
  # This block is not really necessary because chef would automatically backup the file.
  # However, it's good to have the backup file in the same directory. (Easier to find later.)
  ruby_block "backup corosync init script" do
    block do
        original_pathname = "/etc/init.d/corosync"
        backup_pathname = original_pathname + ".old"
        FileUtils.cp(original_pathname, backup_pathname, preserve: true)
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
rubygem_ruby_shadow = "ruby#{node["languages"]["ruby"]["version"].to_f}-rubygem-ruby-shadow"
pkg = package rubygem_ruby_shadow do
  action :nothing
end
pkg.run_action(:install) if node[:platform_family] == "suse"

# After installation of ruby-shadow, we have a new path for the new gem, so we
# need to reset the paths if we can't load ruby-shadow
begin
  require "shadow"
rescue LoadError
  Gem.clear_paths
end

user node[:corosync][:user] do
  action :modify
  # requires ruby-shadow gem
  password node[:corosync][:password]
end

# If this file exists, then we will require that the file gets removed to have
# corosync startable.
#
# If the node goes down properly, then the corosync wrapper/override that we
# install will remove the file, which will allow the wrapper/override to start
# corosync on next boot.
#
# If the node goes down without the proper shutdown process (it has been
# fenced, or it lost power, or it crashed, or...), then the file will exist
# and corosync will not start on next boot, requiring manual intervention.
block_corosync_file = "/var/spool/corosync/block_automatic_start"

sysvinit_corosync_wrapper = "#{node[:corosync][:platform][:service_name]}-wrapper"
systemd_corosync_override_dir = \
  "/etc/systemd/system/#{node[:corosync][:platform][:service_name]}.service.d"

# migration from Crowbar 3.0; can be removed in 5.0
old_corosync_shutdown = "#{node[:corosync][:platform][:service_name]}-shutdown-cleaner"
if File.exist?("/etc/init.d/#{old_corosync_shutdown}") ||
    File.exist?("/etc/systemd/system/#{old_corosync_shutdown}.service")
  service old_corosync_shutdown do
    # There's no need to stop anything here.
    action [:disable]
  end
  file "/etc/init.d/#{old_corosync_shutdown}" do
    action :delete
  end
  file "/etc/systemd/system/#{old_corosync_shutdown}.service" do
    action :delete
  end
  # no need to do systemctl daemon-reload, code below will make it happen
  # since the new override file shouldn't exist yet
end

use_systemd = (node[:platform] != "suse" || node[:platform_version].to_f >= 12.0)
enable_or_disable = :enable

if node[:corosync][:require_clean_for_autostart]
  already_running = system("crm status &> /dev/null")

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
  if ::File.exist?(block_corosync_file) && !already_running
    raise "Not starting #{node[:corosync][:platform][:service_name]} automatically as " \
          "it seems the node was not properly shut down. Please manually start the " \
          "#{node[:corosync][:platform][:service_name]} service, or remove " \
          "#{block_corosync_file} and run chef-client."
  end

  if !use_systemd
    template "/etc/init.d/#{sysvinit_corosync_wrapper}" do
      source "corosync-wrapper.init.erb"
      owner "root"
      group "root"
      mode 0755
      variables(
        service_name: node[:corosync][:platform][:service_name],
        block_corosync_file: block_corosync_file
      )
    end

    # Make sure that any dependency change is taken into account
    bash "insserv #{sysvinit_corosync_wrapper} service" do
      code "insserv #{sysvinit_corosync_wrapper}"
      action :nothing
      subscribes :run, resources(template: "/etc/init.d/#{sysvinit_corosync_wrapper}"), :delayed
    end

    service sysvinit_corosync_wrapper do
      action [:enable, :start]
    end

    # we make sure that corosync is not enabled to start on boot
    enable_or_disable = :disable
  else
    directory systemd_corosync_override_dir do
      owner "root"
      group "root"
      mode "0755"
      action :create
    end

    template "#{systemd_corosync_override_dir}/crowbar.conf" do
      source "corosync.service.override.erb"
      owner "root"
      group "root"
      mode "0644"
      variables(
        block_corosync_file: block_corosync_file
      )
    end

    bash "reload systemd after #{systemd_corosync_override_dir}/crowbar.conf update" do
      code "systemctl daemon-reload"
      action :nothing
      subscribes :run,
        resources(template: "#{systemd_corosync_override_dir}/crowbar.conf"),
        :immediately
    end
  end
else
  if !use_systemd
    # we don't need the wrapper anymore
    service sysvinit_corosync_wrapper do
      action :disable
    end
    file "/etc/init.d/#{sysvinit_corosync_wrapper}" do
      action :delete
    end
  else
    file "#{systemd_corosync_override_dir}/crowbar.conf" do
      action :delete
    end

    bash "reload systemd after #{systemd_corosync_override_dir}/crowbar.conf removal" do
      code "systemctl daemon-reload"
      action :nothing
      subscribes :run,
        resources(file: "#{systemd_corosync_override_dir}/crowbar.conf"),
        :immediately
    end
  end

  file block_corosync_file do
    action :delete
  end
end

service node[:corosync][:platform][:service_name] do
  supports restart: true, status: :true
  unless use_systemd
    action [enable_or_disable, :start]
  end
end

if node[:corosync][:require_clean_for_autostart]
  # we create the file that will block starting corosync on next reboot

  directory ::File.dirname(block_corosync_file) do
    owner "root"
    group "root"
    mode "0700"
    action :create
  end

  # for systemd: the overridden will create the block file; the only case we
  # need to deal with if we enable this feature after corosync is already
  # started
  if !use_systemd || already_running
    file block_corosync_file do
      owner "root"
      group "root"
      mode "0644"
      action :create
    end
  end
end
