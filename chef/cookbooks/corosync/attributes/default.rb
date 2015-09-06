# Copyright 2011, Dell, Inc.
# Copyright 2015, Ovais Tariq <me@ovaistariq.net>
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
default[:corosync][:members]      = []
default[:corosync][:transport]    = "udp"

case node["platform_family"]
when 'suse'
  if node.platform_version.to_f >= 12.0
    default[:corosync][:platform][:packages] = %w(sle-ha-release corosync)
    default[:corosync][:platform][:service_name] = "corosync"
  else
    default[:corosync][:platform][:packages] = %w(sle-hae-release corosync openais)
    default[:corosync][:platform][:service_name] = "openais"
  end

  # The UNIX user for the cluster is typically determined by the
  # cluster-glue package:
  default[:corosync][:platform][:packages].push "cluster-glue"

  default[:corosync][:pacemaker_plugin][:version] = "0"
when 'rhel'
  default[:corosync][:platform][:packages] = %w(corosync)
  default[:corosync][:platform][:service_name] = "corosync"
  default[:corosync][:pacemaker_plugin][:version] = "1"

  # Disabling sslverify for EPEL repository because of a bug with SSL verification
  # on the 6.4 image, otherwise the package ca-certificates needs to be upgraded
  # together with disabling the epel repo when upgrading
  # sudo yum upgrade ca-certificates --disablerepo=epel
  default['yum']['epel']['sslverify'] = false
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
