#
# Author:: Adam Spiers
# Cookbook Name:: pacemaker
# Recipe:: remote
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

# Install and start the pacemaker_remote service.  This recipe makes
# two assumptions:
#
#   - The Pacemaker authkey for communication between corosync nodes
#     and remotes is already set up on all nodes.  The
#     ::authkey_generator and ::authkey_writer recipes will help with
#     this, but it will require some orchestration in order to ensure
#     that the authkey is only generated on one node and then copied
#     to the others without any race conditions.  This is beyond Chef's
#     abilities, so the responsibility is left to the caller.
#
#   - The ocf:pacemaker:remote primitives must not be configured until
#     after this recipe has run and started the pacemaker_remoted
#     services, otherwise the primitives will cause errors.

if node[:pacemaker][:platform][:remote_packages].nil?
  Chef::Application.fatal! "FIXME: #{node.platform} platform not supported yet"
end

node[:pacemaker][:platform][:remote_packages].each do |pkg|
  package pkg
end

service "pacemaker_remote" do
  action [:disable, :start]
end

# Start-up is asynchronous, so make sure the remote is reachable
# before other recipes add the ocf:pacemaker:remote primitives which
# will cause corosync nodes to attempt to contact it.
ruby_block "wait for pacemaker_remote service to be reachable" do
  block do
    require "timeout"
    Timeout.timeout(60) do
      # Later we might introduce a Chef attribute for the port number,
      # but this would require building a template for
      # /etc/sysconfig/pacemaker on remote nodes, so it's not worth
      # the effort until we really need it.
      cmd = "netcat -t localhost 3121 </dev/null"
      until ::Kernel.system(cmd)
        Chef::Log.debug("pacemaker_remote not reachable yet")
        sleep(5)
      end
    end
  end # block
end # ruby_block
