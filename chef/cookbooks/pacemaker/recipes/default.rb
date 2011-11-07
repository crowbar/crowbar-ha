# Copyright 2011 Dell, Inc.
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

# template "/etc/ha.cf" do
#   source 'ha.cf.erb'
#   owner 'root'
#   group 'root'
#   mode '0644'
# end

#enable the corosync service
cookbook_file "/etc/default/corosync" do
  source "corosync"
  owner "root"
  group "root"
  mode "0644"
end

#get the first 3 quads of the IP and add '0'
bindnetaddr = node.ipaddress[0..node.ipaddress.rindex('.')]+'0'

template "/etc/corosync/corosync.conf" do
  source "corosync.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  variables :bindnetaddr => bindnetaddr
end

#start up the corosync service
service "corosync" do
  supports :restart => true, :status => :true
  action [:enable, :start]
  subscribes :restart, resources(:template => "/etc/corosync/corosync.conf"), :immediately
end

#disable stonith
#crm configure property stonith-enabled=false
