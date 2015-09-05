#
# Author:: Ovais Tariq <me@ovaistariq.net>
# Cookbook Name:: pacemaker_test
# Recipe:: drbd
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

# Do base setup common to all the machines
include_recipe "xfs::default"
include_recipe "drbd::pair"

# Make pacemaker-corosync configuration for drbd
# Setup the DRBD volume resource on the founder pacemaker node
drbd_resource_name = "drbd_vol"
drbd_ms_resource_name = "drbd_vol_clone"

pacemaker_primitive drbd_resource_name do
  agent node["pacemaker_test"]["drbd"]["agent"]
  params ({
    "drbd_resource" => node["pacemaker_test"]["drbd"]["resource_name"]
  })
  op node["pacemaker_test"]["drbd"]["op"]
  action :create
  only_if { node[:pacemaker][:founder] }
end

pacemaker_ms drbd_ms_resource_name do
  meta ({
    "master-max" => 1,
    "master-node-max" => 1,
    "clone-max" => 2,
    "clone-node-max" => 1,
    "notify" => "true"
  })
  rsc drbd_resource_name
end

# Setup the filesystem resource on the founder pacemaker node
fs_resource_name = node["pacemaker_test"]["fs"]["resource_name"]

pacemaker_primitive fs_resource_name do
  agent node["pacemaker_test"]["fs"]["agent"]
  params ({
    "device" => "/dev/drbd/by-res/#{node['drbd']['resource_name']}",
    "directory" => node["drbd"]["mount"],
    "fstype" => node["drbd"]["fs_type"],
    "options" => node["drbd"]["mount_options"]
  })
  action :create
  only_if { node[:pacemaker][:founder] }
end

# We colocate drbd and filesystem resources so that both the resources
# are started on the same node, otherwise Pacemaker will balance the different
# resources between different nodes
pacemaker_colocation "#{fs_resource_name}-#{drbd_ms_resource_name}" do
  resources "#{fs_resource_name} #{drbd_ms_resource_name}:Master"
  score "INFINITY"
  only_if { node[:pacemaker][:founder] }
end

pacemaker_order "#{fs_resource_name}-after-#{drbd_ms_resource_name}" do
  ordering "#{drbd_ms_resource_name}:promote #{fs_resource_name}:start"
  score "mandatory"
  only_if { node[:pacemaker][:founder] }
end

# We also need to tell the cluster that Apache needs to run on the same
# machine as the filesystem and that it must be active before Apache can
# start.
haproxy_resource = node["pacemaker_test"]["haproxy"]["resource_name"]
pacemaker_colocation "#{haproxy_resource}-#{fs_resource_name}" do
  resources "#{haproxy_resource} #{fs_resource_name}"
  score "INFINITY"
  only_if { node[:pacemaker][:founder] }
end

pacemaker_order "#{haproxy_resource}-after-#{fs_resource_name}" do
  ordering "#{fs_resource_name} #{haproxy_resource}"
  score "mandatory"
  only_if { node[:pacemaker][:founder] }
end
