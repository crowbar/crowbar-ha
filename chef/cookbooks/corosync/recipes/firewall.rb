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

case node.platform
when 'suse'
  template "/etc/sysconfig/SuSEfirewall2.d/services/cluster" do
    source "firewall.erb"
    mode "0640"
    owner "root"
    variables(
      :mcast_port => node[:corosync][:mcast_port]
    )

    # FIXME: where do I get the name for this from?
    #notifies :restart, "service[#{node[:corosync][:platform][:firewall_name]}]"
  end
end
