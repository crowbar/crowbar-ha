#
# Cookbook Name:: crowbar-pacemaker
# Recipe:: quorum_policy
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

# Enforce no-quorum-policy based on the number of members in the clusters
# We know that for 2 members (or 1, where it doesn't matter), the setting
# should be "ignore". If we have more members, then we use the value set in the
# barclamp.
# For details on the different policies, see
# https://www.suse.com/documentation/sle_ha/book_sleha/data/sec_ha_configuration_basics_global.html
cluster_members_nb = CrowbarPacemakerHelper.num_corosync_nodes(node)
if cluster_members_nb <= 2
  node.default[:pacemaker][:crm][:no_quorum_policy] = "ignore"
end
