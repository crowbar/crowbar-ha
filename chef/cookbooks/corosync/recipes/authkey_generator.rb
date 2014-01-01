#
# Cookbook Name:: corosync
# Recipe:: authkey_generator
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

# Generate the auth key and then save it

# Ensure that the RNG has access to a decent entropy pool,
# so that corosync-keygen doesn't take too long.
package "haveged" do
  action :install
end

service "haveged" do
  action [:enable, :start]
end

authkey_file = node[:corosync][:authkey_file]

# create the auth key
execute "corosync-keygen" do
  creates authkey_file
  user "root"
  group "root"
  umask "0400"
  action :run
end

# Read authkey (it's binary) into encoded format and save to Chef server
ruby_block "Store authkey to Chef server" do
  block do
    file = File.new(authkey_file, 'r')
    contents = ""
    file.each do |f|
      contents << f
    end
    packed = Base64.encode64(contents)
    node.set_unless[:corosync][:authkey] = packed
    node.save
  end
  action :nothing
  subscribes :create, resources(:execute => "corosync-keygen"), :immediately
end
