#
# Cookbook Name:: crowbar-pacemaker
# Recipe:: wait_for_founder
#
# Copyright 2014, SUSE
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

# Simple helper to allow us to correctly synchronize cluster
# initialization: we need the founder to initialize and generate the
# authkey before the other nodes do anything.

require "timeout"

begin
  Timeout.timeout(20) do
    Chef::Log.info("Waiting for cluster founder to be indexed...")
    loop do
      begin
        founder = CrowbarPacemakerHelper.cluster_founder(node)
        Chef::Log.info("Cluster founder found: #{founder.name}")
        break
      rescue
        Chef::Log.info("No cluster founder found yet, waiting...")
        sleep(2)
      end
    end # while true
  end # Timeout
rescue Timeout::Error
  Chef::Log.warn("Cluster founder not found!")
end
