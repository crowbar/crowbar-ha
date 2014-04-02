#
# Author:: Matt Ray <matt@opscode.com>
# Cookbook Name:: drbd
# Recipe:: resource
#
# Copyright 2011, Opscode, Inc
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

node['drbd']['rsc'].keys.sort.each do |resource_name|
  resource = node['drbd']['rsc'][resource_name]

  next if resource["configured"]

  drbd_resource resource_name do
    remote_host resource["remote_host"]
    port (resource["port"] || 7788)
    disk resource["disk"]
    device resource["device"]
    fstype (resource["fstype"] || "xfs")
    master (resource["master"] || false)
    mount resource["mount"]
    action :create
  end

  node['drbd']['rsc'][resource_name]['configured'] = true
  node.save
end
