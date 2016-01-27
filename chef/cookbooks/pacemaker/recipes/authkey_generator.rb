#
# Cookbook Name:: pacemaker
# Recipe:: authkey_generator
#
# Copyright 2015, SUSE
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

# Generate the auth key and then save it.  This is used to establish
# trust between Pacemaker remote nodes and the members of the core
# corosync ring.
#
# N.B. it is not the same auth key which the corosync ring members use
# to establish trust between each other!

require "base64"
require "securerandom"

authkey_file = node[:pacemaker][:authkey_file]

directory File.dirname(authkey_file) do
  owner "root"
  group "root"
  mode "0755"
  action :create
end

# create the auth key
file authkey_file do
  content SecureRandom.random_bytes(4096)
  user node[:pacemaker][:authkey_file_owner]
  group "root"
  mode "0400"
  action :create_if_missing
end

# Read authkey (it's binary) into encoded format and save to Chef server
ruby_block "Store authkey to Chef server" do
  block do
    file = File.new(authkey_file, "r")
    contents = ""
    file.each do |f|
      contents << f
    end
    packed = Base64.encode64(contents)
    node.set_unless[:pacemaker][:authkey] = packed
    node.save
  end
  # If we don't have the attribute, always read the key (even if it existed and
  # we didn't run corosync-keygen)
  unless node[:pacemaker][:authkey].nil?
    action :nothing
    subscribes :create, resources(file: authkey_file), :immediately
  end
end
