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

# With the default bufsize, getting a keystone PKI token from its ID doesn't
# work, because the URI path is too long for haproxy
node.default["haproxy"]["global"]["bufsize"] = 32768

# Always do the setup for haproxy, so that the RA will already be available on
# all nodes when needed (this avoids the need for "crm resource refresh")
include_recipe "haproxy::setup"

cluster_name = CrowbarPacemakerHelper.cluster_name(node)

if node[:pacemaker][:haproxy][:clusters].key?(cluster_name) && node[:pacemaker][:haproxy][:clusters][cluster_name][:enabled]
  nonlocal_bind_file = "/etc/sysctl.d/50-haproxy-nonlocal_bind.conf"
  cookbook_file nonlocal_bind_file do
    source "sysctl_nonlocal_bind.conf"
    mode "0644"
  end

  # we need to reload immediately, as otherwise haproxy would fail to start
  bash "reload nonlocal_bind-sysctl" do
    code "/sbin/sysctl -e -q -p #{nonlocal_bind_file}"
    action :nothing
    subscribes :run, resources(cookbook_file: nonlocal_bind_file), :immediately
  end
end

# Wait for all nodes to reach this point so we know that all nodes will have
# all the required packages installed before we create the pacemaker
# resources
crowbar_pacemaker_sync_mark "sync-haproxy_before_ha" do
  revision node[:pacemaker]["crowbar-revision"]
end

# Avoid races when creating pacemaker resources
crowbar_pacemaker_sync_mark "wait-haproxy_ha_resources" do
  revision node[:pacemaker]["crowbar-revision"]
end

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

  # Compatibility with existing deployment: we need to drop the group to create
  # the clone
  group_name = "g-#{service_name}"
  # drop location constraint first as it would get reassigned to some child of the group
  # otherwise. See: https://github.com/ClusterLabs/crmsh/issues/140
  pacemaker_location openstack_pacemaker_controller_only_location_for group_name do
    action :delete
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  pacemaker_group group_name do
    action [:stop, :delete]
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
    only_if "crm configure show #{group_name}"
  end

  # Create VIP for HAProxy
  node[:pacemaker][:haproxy][:clusters][cluster_name][:networks].each do |network, enabled|
    ip_addr = CrowbarPacemakerHelper.cluster_vip(node, network)
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
    location_name = openstack_pacemaker_controller_only_location_for vip_primitive
    transaction_objects << "pacemaker_location[#{location_name}]"
  end

  pacemaker_primitive service_name do
    agent node[:pacemaker][:haproxy][:agent]
    op node[:pacemaker][:haproxy][:op]
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  transaction_objects << "pacemaker_primitive[#{service_name}]"

  clone_name = "cl-#{service_name}"
  pacemaker_clone clone_name do
    rsc service_name
    meta ({
      "clone-max" => CrowbarPacemakerHelper.num_corosync_nodes(node),
      "interleave" => "true"
    })
    action :update
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
  transaction_objects << "pacemaker_clone[#{clone_name}]"

  if node[:pacemaker][:haproxy][:for_openstack]
    location_name = openstack_pacemaker_controller_only_location_for clone_name
    transaction_objects << "pacemaker_location[#{location_name}]"
  end

  pacemaker_transaction "haproxy service" do
    cib_objects transaction_objects
    # note that this will also automatically start the resources
    action :commit_new
    only_if { CrowbarPacemakerHelper.is_cluster_founder?(node) }
  end
end

crowbar_pacemaker_sync_mark "create-haproxy_ha_resources" do
  revision node[:pacemaker]["crowbar-revision"]
end
