# Cookbook Name:: crowbar-pacemaker
# Provider:: service
#
# Copyright:: 2014, SUSE
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

# This is an alternative provider for Chef's "service" platform resource.
# It allows us to make an existing service resource Pacemaker-aware by
# adding a single line:
#
#   service "foo" do
#     service_name ...
#     supports :status => true, :start => true, :restart => true
#     action [ :enable, :start ]
#     subscribes :restart, resources(:template => "/etc/foo.conf")
#     provider Chef::Provider::CrowbarPacemakerService if ha_enabled
#   end
#
# This effectively disables most of the resource's standard functionality,
# the expectation being that you will also define a pacemaker_primitive
# resource after this service block, which will cause Pacemaker to assume
# management of the service.

require "mixlib/shellout"

this_dir = ::File.dirname(__FILE__)
require ::File.expand_path("../libraries/maintenance_mode_helpers", this_dir)

# Disable the traditional service since it should only ever be started
# by Pacemaker - if you violate that contract with Pacemaker then it
# can get very confused and Bad Things will probably happen.
[:enable, :disable].each do |a|
  action a do
    name = new_resource.service_name
    Chef::Log.info("Disabling #{name} service; will be managed by Pacemaker instead")
    proxy_action(new_resource, :disable)
  end
end

[:start, :stop].each do |a|
  action a do
    name = new_resource.service_name
    # Similarly to above, ignore start/stop since this will be handled
    # by the pacemaker_primitive LWRP instead.
    Chef::Log.info("Ignoring #{a} action for #{name} service since managed by Pacemaker instead")
  end
end

# We still have to honour restart.  This is because some service
# resources will have a "subscribes" line like the above, for handling
# when some aspect of the service's configuration changes.
#
# This is surprisingly tricky to do right.  We have to perform the
# restart in a way which does not violate the contract we have
# regarding Pacemaker "owning" management of the service.  So there
# are only two options: either the restart has to be done through the
# Pacemaker interface, or we have to temporarily suspend Pacemaker's
# management of the service.
#
# Secondly, chef-client will run on every node in the cluster, but
# Pacemaker operations are cluster-wide because they affect the CIB
# rather than individual nodes directory.  So for example we can't
# just do a "crm resource restart $service" on each node, because that
# would result in n attempts to restart the service, which could quite
# possibly happen in a near simultaneous fashion (if triggered as part
# of a proposal being applied).
#
# A similar synchronization problem occurs if we attempt to
# temporarily "unmanage" the service (either by setting
# is-managed="false" or setting the resource's maintenance mode flag
# to true, the latter requiring a package update since it was only
# introduced since the GM release of HAE for SLES11 SP3), then restart
# the service ourselves, and then restore the maintenance mode flag
# back to false - since this flag is cluster-wide, multiple nodes
# would race over its value, so the only viable solution would be a
# global lock which would cause the chef-clients to block in a serial
# fashion, and that obviously sucks.
#
# One approach considered was to handle restart of the resource
# through Pacemaker, but in the case where it could be running on
# multiple nodes, handle the restart separately for each node.
# However, we don't know in advance on which node(s) in the cluster
# the resource is running.  Even if it's a clone, there's no guarantee
# that it's running on all nodes (e.g. clone-max could be less than
# the number of nodes in the cluster).  So we need to ensure that we
# only attempt a restart if the resource is running on *this* node
# (the one on which the chef-client is running).
#
# Unfortunately, Pacemaker doesn't provide any native way to restart
# an individual clone.  So the best we could do in the clone case is
# to temporarily force Pacemaker to stop the clone instance on this
# node, and then remove that restriction.  This could be achieved by
# creating a temporary -infinity location constraint which prohibits
# the resource from running on this node, waiting for it to take
# effect, and then removing the constraint.  But that has the
# unfortunate side effect of potentially starting up the resource on a
# different node.
#
# There are several further complications to this approach.  The
# "service" resource (the one this provider will be consumed by) would
# need to know, or at least be able to programmatically figure out the
# name of the clone on whose behalf it can perform the restart action.
# This is not just an "inappropriate intimacy" code smell, but also
# impossible to implement in a way which would support a clone of a
# group of services.  It's not possible for an alternate provider to
# widen the attributes the resource accepts, and the cluster resource
# name cannot be passed via the existing "service_name" attribute
# (since that has to refer to the LSB service name).  So either the
# "service" resource gets named after the Pacemaker resource requiring
# the restart, in which case it may violate Chef's requirement for
# resources of a given type to have unique names (since several
# "service" resources within a cloned group would then end up with the
# same clone name), or some naming scheme enforced by helper methods
# is relied upon, but embedding relationship cardinality meta-data
# into this namespace is very problematic.
#
# Also, by restarting via Pacemaker, there is no way to restart the
# one service in the group without also restarting the others (in the
# case where the service is not the last one to start up).
#
# After all those considerations, it turns out that the cleanest
# solution is to use Pacemaker's ability to put individual *nodes*
# (not resources) into maintenance mode.  This way we can safely
# restart the resource in the normal way (i.e. not via Pacemaker),
# without worrying of any of the above, or requiring any knowledge of
# the cluster resource configuration.  It's also semantically cleaner,
# because Chef runs perform operations which can certainly be
# considered as genuine maintenance (albeit automated).  So this may
# protect us against other things we haven't yet encountered.
#
# Taking a node out of maintenance mode will trigger a re-probe for
# all the resources on that node.  Therefore we want to avoid toggling
# maintenance mode on the node multiple times during a single
# chef-client run.  To achieve this, we enable maintenance mode for
# the node when the first restart action is encountered, and add a
# report handler to Chef so that at the end of the run, maintenance
# mode is disabled if need be.  This will leave the node in
# maintenance mode if either:
#
#   1. it already was at the beginning of the chef-client run, or
#
#   2. the chef-client run fails, in which case it is expected that it
#      is more commonly a good thing than a bad one to leave it in
#      maintenance mode, since manual clean-up would typically be
#      required at that point.
#
#
# In addition to the above, we support a "restart_crm_resource" flag that tells
# us to use crm_resource for restarting the service. This is useful for
# resources that are defined with an OCF agent: in that case, we can't proxy
# the restart action to a LSB init script or systemd. Note that we bypass the
# cluster by using --force-stop / --force-start, which has the benefit of not
# respecting constraints, or starting the resource elsewhere (so there's no
# side-effect due to the restart).
#
#
# We also support a "no_crm_maintenance_mode" flag that tells us to not move
# the node to maintenance mode. It seems maintenance mode does not work for
# remote nodes, so it is a workaround for them.

include CrowbarPacemaker::MaintenanceModeHelpers

action :restart do
  resource = new_resource.name
  service_name = new_resource.service_name
  this_node = node.hostname
  use_crm_resource = new_resource.supports[:restart_crm_resource]
  no_maintenance_mode = new_resource.supports[:no_crm_maintenance_mode]
  pacemaker_resource = new_resource.supports[:pacemaker_resource_name] || service_name

  if service_is_running?(service_name, use_crm_resource, pacemaker_resource)
    set_maintenance_mode unless no_maintenance_mode

    if use_crm_resource
      bash "crm_resource --force-stop / --force-start  --resource #{pacemaker_resource}" do
        code <<-EOH
          crm_resource --force-stop --resource #{pacemaker_resource} && \
          crm_resource --force-start --resource #{pacemaker_resource}
          EOH
        action :nothing
      end.run_action(:run)
    else
      proxy_action(new_resource, :restart)
    end
  else
    Chef::Log.info("Ignoring restart action for #{resource} service since not running on this node (#{this_node})")
  end
end

# We also have to honour :reload, for similar reasons to :restart.
# However, a reload does not stop a running service, so it's safe to
# do directly via the service with no risk of confusing Pacemaker.
action :reload do
  service_name = new_resource.service_name
  use_crm_resource = new_resource.supports[:restart_crm_resource]

  if use_crm_resource
    Chef::Log.info("Ignoring reload action for #{service_name} service since not compatible with 'restart_crm_resource' flag")
    return
  end

  if service_is_running?(service_name, false, service_name)
    proxy_action(new_resource, :reload)
  else
    Chef::Log.info("Ignoring reload action for #{service_name} service since not running on this node (#{node.hostname})")
  end
end

def service_is_running?(name, use_crm_resource, pacemaker_resource)
  if use_crm_resource
    `crm_resource --force-check --resource #{pacemaker_resource}`
    # For Master/Slave resources "monitor" will return OCF_RUNNING_MASTER (8)
    # on nodes that are running the resource in Master role currently. We need
    # to treat that as a successfully result as well.
    $?.success? || $?.exitstatus == 8
  else
    `service #{name} status`
    $?.success?
  end
end

def proxy_action(resource, service_action)
  # This service name needs to be unique per resource *and* action,
  # otherwise we get warnings about the resource attributes being
  # cloned from the prior resource (CHEF-3694).
  service "pacemaker-#{service_action}-of-#{resource.name}" do
    supports restart: true, reload: true
    service_name resource.service_name
    action :nothing
  end.run_action(service_action)
end
