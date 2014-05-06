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

default[:corosync][:cluster_name] = "hacluster"

default[:corosync][:bind_addr ]   = "192.168.124.0"
default[:corosync][:mcast_addr]   = "239.1.2.3"
default[:corosync][:mcast_port]   = 5405

case node.platform
when 'suse'
  default[:corosync][:platform][:packages] = %w(sle-hae-release corosync openais)

  # The UNIX user for the cluster is typically determined by the
  # cluster-glue package:
  default[:corosync][:platform][:packages].push "cluster-glue"

  default[:corosync][:platform][:service_name] = "openais"
else
  # FIXME: untested, probably wrong
  default[:corosync][:platform][:packages] = %w(corosync)
  default[:corosync][:platform][:service_name] = "corosync"
end

# values should be 'yes' or 'no'.
default[:corosync][:enable_openais_service] = "yes"

default[:corosync][:user] = "hacluster"

# The cloud operator should modify the password at proposal creation
# time.  We can't set it to something random because that's how Hawk
# provides authentication.
default[:corosync][:password] = "$1$0w6d0uZu$QK13Hun/7Xa3NP1bjLfe5/" # crowbar

default[:corosync][:authkey_file] = "/etc/corosync/authkey"

default[:corosync][:require_clean_for_autostart] = false
