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

require "timeout"

#
# Synchronization helpers
#
# With crowbar, we will need chef runs on different nodes of a cluster to
# "synchronize" to avoid some resources being created too early, or to allow
# one cluster member (the founder) to do something first, before the others.
#
# Therefore we offer two sets of helpers:
#
#  - "founder goes first" synchronization:
#
#    In this model, all nodes must call #wait_for_mark_from_founder. The
#    non-founder nodes will block there, while the founder will not block and
#    hence execute the following code first. A later call to
#    #set_mark_if_founder will allow the founder to unblock the other nodes.
#
#    This is used when an action executed on several nodes at the same time
#    can create a crash due to a race. For instance, creating a pacemaker
#    primitive.
#
#  - "wait for all nodes" synchronization:
#
#    In this model, all nodes must call #synchronize_on_mark. Nodes will then
#    block until this call has been done by all nodes.
#
# The synchronization is used through a mark, which uses a name to guarantee
# its uniqueness.
#
# Calls to #wait_for_mark_from_founder and #synchronize_on_mark can fail if
# synchronization failed. By default, a failure is not fatal, but the fatal
# argument can be used to abort the chef run.
#

module CrowbarPacemakerSynchronization
  def self.prefix
    "crowbar_sync-"
  end

  # See "Synchronization helpers" documentation
  def self.wait_for_mark_from_founder(node, mark, fatal = false, timeout = 60)
    return unless CrowbarPacemakerHelper.cluster_enabled?(node)
    return if CrowbarPacemakerHelper.is_cluster_founder?(node)
    if CrowbarPacemakerHelper.being_upgraded?(node)
      Chef::Log.debug("Node is being upgraded." \
        "Skipping wait loop for cluster founder.")
      return
    end

    Chef::Log.info("Checking if cluster founder has set #{mark}...")

    founder_name = CrowbarPacemakerHelper.cluster_founder_name(node)

    begin
      Timeout.timeout(timeout) do
        loop do
          if CrowbarPacemakerCIBAttribute.get(founder_name, "#{prefix}#{mark}", "0") != "0"
            Chef::Log.info("Cluster founder has set #{mark}.")
            break
          end
          Chef::Log.debug("Waiting for cluster founder to set #{mark}...")
          sleep(5)
        end # loop
      end # Timeout
    rescue Timeout::Error
      if fatal
        message = "Cluster founder didn't set #{mark}!"
        Chef::Log.fatal(message)
        raise message
      else
        message = "Cluster founder didn't set #{mark}! Going on..."
        Chef::Log.warn(message)
      end
    end
  end

  # See "Synchronization helpers" documentation
  def self.set_mark_if_founder(node, mark)
    return unless CrowbarPacemakerHelper.cluster_enabled?(node)
    return unless CrowbarPacemakerHelper.is_cluster_founder?(node)

    if CrowbarPacemakerCIBAttribute.get(node[:hostname], "#{prefix}#{mark}", "0") != "0"
      Chef::Log.info("Synchronization cluster mark #{mark} already set.")
    else
      Chef::Log.info("Setting synchronization cluster mark #{mark}.")
      CrowbarPacemakerCIBAttribute.set(node[:hostname], "#{prefix}#{mark}", "1")
    end
  end

  # See "Synchronization helpers" documentation
  def self.synchronize_on_mark(node, mark, fatal = false, timeout = 60)
    return unless CrowbarPacemakerHelper.cluster_enabled?(node)

    # non-founders simply set the mark and then wait for the founder to set the
    # mark
    unless CrowbarPacemakerHelper.is_cluster_founder?(node)
      Chef::Log.info("Setting synchronization cluster mark #{mark}.")
      CrowbarPacemakerCIBAttribute.set(node[:hostname], "#{prefix}#{mark}", "1")
      return wait_for_mark_from_founder(node, mark, fatal, timeout)
    end

    # founder waits for the mark to be set on all non-founders, and then sets
    # its mark; if the mark is already set, we can skip everything
    if CrowbarPacemakerCIBAttribute.get(node[:hostname], "#{prefix}#{mark}", "0") != "0"
      Chef::Log.info("Synchronization cluster mark #{mark} already set.")
      return
    end

    if CrowbarPacemakerHelper.being_upgraded?(node)
      Chef::Log.debug("Node is being upgraded." \
        "Skipping wait loop for all other cluster nodes.")
    else
      begin
        Chef::Log.info("Checking if all other cluster nodes have set #{mark}...")

        Timeout.timeout(timeout) do
          CrowbarPacemakerHelper.cluster_nodes_names(node).each do |name|
            next if name == node[:hostname]
            loop do
              break if CrowbarPacemakerCIBAttribute.get(name, "#{prefix}#{mark}", "0") != "0"
              Chef::Log.debug("Waiting for all other cluster nodes to set #{mark}...")
              sleep(5)
            end
          end # each
        end # Timeout
      rescue Timeout::Error
        if fatal
          message = "Some cluster nodes didn't set #{mark}!"
          Chef::Log.fatal(message)
          raise message
        else
          message = "Some cluster nodes didn't set #{mark}! Going on..."
          Chef::Log.warn(message)
        end
      end
    end

    Chef::Log.info("Setting synchronization cluster mark #{mark}.")
    CrowbarPacemakerCIBAttribute.set(node[:hostname], "#{prefix}#{mark}", "1")
  end

  def self.reset_marks(node)
    attributes = CrowbarPacemakerCIBAttribute.list(node[:hostname])
    attributes.select! { |k, v| k =~ /^#{prefix}/ }
    attributes.each_key do |attribute|
      CrowbarPacemakerCIBAttribute.unset(node[:hostname], attribute)
    end
  end

  def self.migrate_sync_marks_v1(node)
    return unless CrowbarPacemakerHelper.cluster_enabled?(node)

    cluster_name = CrowbarPacemakerHelper.cluster_name(node)
    return if node[:pacemaker][:sync_marks][cluster_name].nil?

    node[:pacemaker][:sync_marks][cluster_name].each_key do |mark|
      CrowbarPacemakerCIBAttribute.set(node[:hostname], "#{prefix}#{mark}", "1")
    end
  end
end
