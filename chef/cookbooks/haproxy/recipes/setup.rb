#
# Cookbook Name:: haproxy
# Recipe:: setup
#
# Copyright 2014, SUSE
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

package node[:haproxy][:platform][:package]

template node[:haproxy][:platform][:config_file] do
  source "haproxy.cfg.erb"
  owner "root"
  group "root"
  mode 00644
end

# Make sure that systemd kills haproxy services when restart action is requested.
# It's possible haproxy is unable to close open connections during restart
# so we make sure systemd kills it before we hit pacemaker service
# timeout that would ultimately fence the haproxy node (bsc#1056371).

systemd_override_dir = \
  "/etc/systemd/system/#{node[:haproxy][:platform][:package]}.service.d"

directory systemd_override_dir do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

cookbook_file "#{systemd_override_dir}/10-timeout.conf" do
  source "haproxy.service.override.conf"
  owner "root"
  group "root"
  mode "0644"
end
