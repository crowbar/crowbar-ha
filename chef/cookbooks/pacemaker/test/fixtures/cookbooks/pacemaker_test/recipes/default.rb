#
# Author:: Ovais Tariq <me@ovaistariq.net>
# Cookbook Name:: pacemaker_test
# Recipe:: default
#
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

# Do base corosync and pacemaker cluser setup and configuration
include_recipe "pacemaker::default"

# Setup the cluster VIP on the founder pacemaker node
vip_resource_name = node["pacemaker_test"]["virtual_ip"]["resource_name"]

pacemaker_primitive vip_resource_name do
  agent node["pacemaker_test"]["virtual_ip"]["agent"]
  params ({
    "ip" => node["pacemaker_test"]["cluster_vip"],
    "cidr_netmask" => 24
  })
  op node["pacemaker_test"]["virtual_ip"]["op"]
  action :create
  only_if { node[:pacemaker][:founder] }
end

# Setup haproxy
include_recipe "pacemaker_test::haproxy"

# Setup DRBD
include_recipe "pacemaker_test::drbd"
