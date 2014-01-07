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

service node[:corosync][:platform][:service_name] do
  supports :restart => true, :status => :true
  action [:enable, :start]
end
