#
# Author:: Vincent Untz
# Cookbook Name:: crowbar-pacemaker
# Recipe:: attributes
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

CrowbarPacemakerHelper.remote_nodes(node).each do |remote|
  remote[:pacemaker][:attributes].each do |attr, value|
    execute %(set pacemaker attribute "#{attr}" to "#{value}" on remote #{remote[:hostname]}) do
      command %(crm node attribute remote-#{remote[:hostname]} set "#{attr}" "#{value}")
      # The cluster only does a transition if the attribute value changes,
      # so checking the value before setting would only slow things down
      # for no benefit.
      only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
    end
  end
end
