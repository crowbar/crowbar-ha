#
# Author:: Vincent Untz
# Cookbook Name:: crowbar-pacemaker
# Recipe:: openstack
#
# Copyright 2016, SUSE
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

# if we ever want to not have a hard dependency on openstack here, we can have
# Crowbar set a node[:pacemaker][:resource_agents] attribute based on available
# barclamps, and do:
# node[:pacemaker][:resource_agents].each do |resource_agent|
#   node[:pacemaker][:platform][:resource_packages][resource_agent].each do |pkg|
#     package pkg
#   end
# end
node[:pacemaker][:platform][:resource_packages][:openstack].each do |pkg|
  package pkg
end
