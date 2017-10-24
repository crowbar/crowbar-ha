#
# Cookbook Name:: corosync
# Recipe:: firewall
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

mcast_ports = node[:corosync][:rings].map { |n| n["mcast_port"] }
if node[:corosync][:transport] == "udp"
  # Corosync uses the port you specify for UDP messaging, and also the
  # immediately preceding port. Thus if you specify 5405, Corosync
  # sends messages from UDP port 5404 to UDP port 5405.
  mcast_ports += mcast_ports.map { |n| n - 1 }
end
mcast_ports = mcast_ports.uniq.sort

case node[:platform_family]
when "suse"
  template "/etc/sysconfig/SuSEfirewall2.d/services/cluster" do
    source "firewall.erb"
    mode "0640"
    owner "root"
    variables(
      mcast_ports: mcast_ports
    )

    # FIXME: where do I get the name for this from?
    #notifies :restart, "service[#{node[:corosync][:platform][:firewall_name]}]"
  end
end
