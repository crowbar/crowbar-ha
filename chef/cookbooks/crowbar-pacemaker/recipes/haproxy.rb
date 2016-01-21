#
# Cookbook Name:: crowbar-pacemaker
# Recipe:: haproxy
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

#FIXME: delete group when it's not needed anymore
#FIXME: need to find/write OCF for haproxy

# Recommendation from the OpenStack HA guide is to use "source" as balance
# algorithm. This obviously is less useful for load balancing, but we care more
# about HA and things working than about load balancing.
node.default["haproxy"]["defaults"]["balance"] = "source"

# With the default bufsize, getting a keystone PKI token from its ID doesn't
# work, because the URI path is too long for haproxy
node.default["haproxy"]["global"]["bufsize"] = 32768

# Always do the setup for haproxy, so that the RA will already be available on
# all nodes when needed (this avoids the need for "crm resource refresh")
include_recipe "haproxy::setup"

cluster_name = CrowbarPacemakerHelper.cluster_name(node)

if node[:pacemaker][:haproxy][:clusters].key?(cluster_name) && node[:pacemaker][:haproxy][:clusters][cluster_name][:enabled]
  service "haproxy" do
    supports restart: true, status: true, reload: true
    action :nothing
    subscribes :reload, "template[#{node[:haproxy][:platform][:config_file]}]", :immediately
    provider Chef::Provider::CrowbarPacemakerService
  end

  transaction_objects = []
  vip_primitives = []

  cluster_vhostname = CrowbarPacemakerHelper.cluster_vhostname(node)
  service_name = "haproxy"

  # Create VIP for HAProxy
  node[:pacemaker][:haproxy][:clusters][cluster_name][:networks].each do |network, enabled|
    net_db = data_bag_item("crowbar", "#{network}_network")
    raise "#{network}_network data bag missing?!" unless net_db
    fqdn = "#{cluster_vhostname}.#{node[:domain]}"
    unless net_db["allocated_by_name"][fqdn]
      raise "Missing allocation for #{fqdn} in #{network} network"
    end
    ip_addr = net_db["allocated_by_name"][fqdn]["address"]

    vip_primitive = "vip-#{network}-#{cluster_vhostname}"
    pacemaker_primitive vip_primitive do
      agent "ocf:heartbeat:IPaddr2"
      params ({
        "ip" => ip_addr
      })
      op node[:pacemaker][:haproxy][:op]
      action :update
      only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
    end
    vip_primitives << vip_primitive
    transaction_objects << "pacemaker_primitive[#{vip_primitive}]"
  end

  pacemaker_primitive service_name do
    agent node[:pacemaker][:haproxy][:agent]
    op node[:pacemaker][:haproxy][:op]
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  transaction_objects << "pacemaker_primitive[#{service_name}]"

  group_name = "g-#{service_name}"
  pacemaker_group group_name do
    # Membership order *is* significant; VIPs should come first so
    # that they are available for the haproxy service to bind to.
    members vip_primitives.sort + [service_name]
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  transaction_objects << "pacemaker_group[#{group_name}]"

  if node[:pacemaker][:haproxy][:for_openstack]
    location_name = openstack_pacemaker_controller_only_location_for group_name
    transaction_objects << "pacemaker_location[#{location_name}]"
  end

  pacemaker_transaction "haproxy service" do
    cib_objects transaction_objects
    # note that this will also automatically start the resources
    action :commit_new
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
end
