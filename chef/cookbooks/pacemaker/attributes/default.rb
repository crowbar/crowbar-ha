# Copyright 2011, Dell, Inc.
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

case node[:platform_family]
when "suse"
  default[:pacemaker][:platform][:packages] =
    %w(pacemaker crmsh fence-agents)
  default[:pacemaker][:platform][:remote_packages] =
    %w(pacemaker-remote fence-agents)
else

  #
  # These ubuntu package requirements have to be validated before we will
  # activate that, these packages have been taken from an old notes file:
  #
  # * libcluster-glue
  # * libnet1
  # * libopenhpi2
  # * libopenipmi0
  # * cluster-glue
  # * cluster-agents
  # * libcorosync4
  # * corosync
  # * libesmtp5
  # * libheartbeat2
  # * libxslt1.1
  # * openhpid
  # * pacemaker
  # * haveged
  #

  default[:pacemaker][:platform][:packages] = nil
end

default[:pacemaker][:founder] = false
default[:pacemaker][:remote] = false
default[:pacemaker][:crm][:initial_config_file] = "/etc/corosync/crm-initial.conf"
default[:pacemaker][:crm][:no_quorum_policy] = "ignore"
default[:pacemaker][:crm][:op_default_timeout] = 60

# Values can be "disabled", "manual", "sbd", "shared", "per_node"
default[:pacemaker][:stonith][:mode] = "disabled"

# This hash will contain devices for each node.
# For instance:
#  default[:pacemaker][:stonith][:sbd][:nodes][$node][:devices] = ['/dev/disk/by-id/foo-part1', '/dev/disk/by-id/bar-part1']
default[:pacemaker][:stonith][:sbd][:nodes] = {}

# kernel module to use for watchdog
default[:pacemaker][:stonith][:sbd][:watchdog_module] = ""

default[:pacemaker][:stonith][:shared][:agent] = ""
# This can be either a string (containing a list of parameters) or a hash.
# For instance:
#   default[:pacemaker][:stonith][:shared][:params] = 'hostname="foo" password="bar"'
# will give the same result as:
#   default[:pacemaker][:stonith][:shared][:params] = {"hostname" => "foo", "password" => "bar"}
default[:pacemaker][:stonith][:shared][:params] = {}

default[:pacemaker][:stonith][:per_node][:agent] = ""
# This can be "all" or "self":
#   - if set to "all", then every node will configure the stonith resources for
#     all nodes in the cluster
#   - if set to "self", then every node will configure the stonith resource for
#     itself only
default[:pacemaker][:stonith][:per_node][:mode] = "all"
# This hash will contain parameters for each node. See documentation for
# default[:pacemaker][:stonith][:shared][:params] about the format.
# For instance:
#  default[:pacemaker][:stonith][:per_node][:nodes][$node][:params] = 'hostname="foo" password="bar"'
default[:pacemaker][:stonith][:per_node][:nodes] = {}

default[:pacemaker][:notifications][:agent] = "ocf:heartbeat:ClusterMon"
default[:pacemaker][:notifications][:smtp][:enabled] = false
default[:pacemaker][:notifications][:smtp][:to] = ""
default[:pacemaker][:notifications][:smtp][:from] = ""
default[:pacemaker][:notifications][:smtp][:server] = ""
default[:pacemaker][:notifications][:smtp][:prefix] = ""

default[:pacemaker][:authkey_file] = "/etc/pacemaker/authkey"
default[:pacemaker][:authkey_file_owner] = "hacluster" # same as default[:corosync][:user]
