#
# Cookbook Name:: crowbar-haproxy
# Recipe:: default
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

# We're in the pacemaker barclamp, so we're using the pacemaker namespace

default[:pacemaker][:platform][:resource_packages][:openstack] = %w(openstack-resource-agents)

if node[:platform] == "suse" && node[:platform_version].to_f < 12.0
  # SLE11
  default[:pacemaker][:apache2][:agent] = "ocf:heartbeat:apache"
  default[:pacemaker][:haproxy][:agent] = "lsb:haproxy"
else
  default[:pacemaker][:apache2][:agent] = "systemd:apache2"
  default[:pacemaker][:haproxy][:agent] = "systemd:haproxy"
end
default[:pacemaker][:haproxy][:op][:monitor][:interval] = "10s"
default[:pacemaker][:haproxy][:clusters] = {}

default[:pacemaker][:remote][:agent] = "ocf:pacemaker:remote"
default[:pacemaker][:remote][:op][:monitor][:interval] = "20s"
default[:pacemaker][:remote][:op][:start][:timeout] = "60s"
default[:pacemaker][:remote][:op][:stop][:timeout] = "60s"
default[:pacemaker][:remote][:params][:reconnect_interval] = "60s"
