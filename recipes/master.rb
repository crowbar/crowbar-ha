#
# Cookbook Name:: corosync
# Recipe:: server
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

require 'base64'

# from https://github.com/mattray/barclamp_ha_service/blob/pacemaker_service/chef/cookbooks/pacemaker/recipes/master.rb

# install the corosync package
package "corosync" do
  action :upgrade
end

# create the auth key
execute "corosync-keygen" do
  creates "/etc/corosync/authkey"
  user "root"
  group "root"
  umask "0400"
  action :run
end

# Read authkey (it's binary) into encoded format and save to chef server
ruby_block "Store authkey" do
  block do
    file = File.new('/etc/corosync/authkey', 'r')
    contents = ""
    file.each do |f|
      contents << f
    end
    packed = Base64.encode64(contents)
    node.set_unless['corosync']['authkey'] = packed
    node.save
  end 
  action :nothing
  subscribes :create, resources(:execute => "corosync-keygen"), :immediately
end

include_recipe "corosync::client"
