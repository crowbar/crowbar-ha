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
# The synchronization is used through a mark. This mark is made unique
# through the name of the cluster (automatically computed) and the name of
# the mark (must be passed as argument).
#
# The mark will then be created with a revision; this way, on later runs, if
# the methods are called with the same revision, then nothing will block as
# we will know that the mark is already correct.
#
# Calls to #wait_for_mark_from_founder and #synchronize_on_mark can fail if
# synchronization failed. By default, a failure is not fatal, but the fatal
# argument can be used to abort the chef run.
#

module CrowbarPacemakerSynchronization

  def self.founder_at_revision(founder, cluster_name, mark, revision)
    return false if founder.nil?
    current_rev = \
      begin
        founder[:pacemaker][:sync_marks][cluster_name][mark]
      rescue NoMethodError
        nil
      end
    current_rev == revision
  end

  # See "Synchronization helpers" documentation
  def self.wait_for_mark_from_founder(node, mark, revision, fatal = false, timeout = 60)
    return unless CrowbarPacemakerHelper.cluster_enabled?(node)
    return if CrowbarPacemakerHelper.is_cluster_founder?(node)
    if CrowbarPacemakerHelper.being_upgraded?(node)
      Chef::Log.debug("Node is being upgraded." \
        "Skipping wait loop for cluster founder.")
      return
    end

    cluster_name = CrowbarPacemakerHelper.cluster_name(node)

    Chef::Log.info("Checking if #{cluster_name} cluster founder has set #{mark} to #{revision}...")

    founder_name = "<unknown>"
    begin
      Timeout.timeout(timeout) do
        while true
          founder = CrowbarPacemakerHelper.cluster_founder(node)
          founder_name = founder.hostname

          if founder_at_revision(founder, cluster_name, mark, revision)
            Chef::Log.info("Cluster founder #{founder_name} has set #{mark} to #{revision}.")
            break
          end

          Chef::Log.debug("Waiting for cluster founder #{founder_name} " \
                          "to set #{mark} to #{revision}...")
          sleep(5)
        end # while true
      end # Timeout
    rescue Timeout::Error
      if fatal
        message = \
          "Cluster founder #{founder_name} didn't set #{mark} " \
          "to #{revision}! Timed out while waiting for the founder; " \
          "Please check the chef-client logs for that node to see " \
          "what went wrong."
        Chef::Log.fatal(message)
        raise message
      else
        message = \
          "Cluster founder #{founder_name} didn't set #{mark} " \
          "to #{revision}! Going on..."
        Chef::Log.warn(message)
      end
    end
  end

  # See "Synchronization helpers" documentation
  def self.set_mark_if_founder(node, mark, revision)
    return unless CrowbarPacemakerHelper.cluster_enabled?(node)
    return unless CrowbarPacemakerHelper.is_cluster_founder?(node)

    cluster_name = CrowbarPacemakerHelper.cluster_name(node)

    node[:pacemaker][:sync_marks] ||= {}
    node[:pacemaker][:sync_marks][cluster_name] ||= {}
    if node[:pacemaker][:sync_marks][cluster_name][mark] != revision
      node[:pacemaker][:sync_marks][cluster_name][mark] = revision
      node.save
      Chef::Log.info("Setting founder cluster mark #{mark} to #{revision}.")
    else
      Chef::Log.info("Founder cluster mark #{mark} already set to #{revision}.")
    end
  end

  # See "Synchronization helpers" documentation
  def self.synchronize_on_mark(node, mark, revision, fatal = false, timeout = 60)
    return unless CrowbarPacemakerHelper.cluster_enabled?(node)

    cluster_name = CrowbarPacemakerHelper.cluster_name(node)

    node[:pacemaker][:sync_marks] ||= {}
    node[:pacemaker][:sync_marks][cluster_name] ||= {}
    if node[:pacemaker][:sync_marks][cluster_name][mark] != revision
      node[:pacemaker][:sync_marks][cluster_name][mark] = revision
      node.save
      Chef::Log.info("Setting synchronization cluster mark #{mark} to #{revision}.")
    else
      Chef::Log.info("Synchronization cluster mark #{mark} already set to #{revision}.")
    end

    cluster_nodes = CrowbarPacemakerHelper.cluster_nodes(node).map(&:name)
    raise "No member in the cluster!" if cluster_nodes.empty?

    if CrowbarPacemakerHelper.being_upgraded?(node)
      Chef::Log.debug("Node is being upgraded." \
        "Skipping wait loop for all other cluster nodes.")
      return
    end

    Chef::Log.info("Checking if all #{cluster_name} cluster nodes have " \
                   "set #{mark} to #{revision}...")

    nodes_with_mark_set = []
    begin
      Timeout.timeout(timeout) do
        while true
          nodes_with_mark_set = []
          Chef::Search::Query.new.search(
            :node,
            "pacemaker_config_environment:#{node[:pacemaker][:config][:environment]} " \
            "AND pacemaker_sync_marks_#{cluster_name}_#{mark}:#{revision}"
          ) do |o|
            nodes_with_mark_set << o.name
          end

          remaining = cluster_nodes - nodes_with_mark_set
          if remaining.empty?
            Chef::Log.info("All cluster nodes have set #{mark} to #{revision}.")
            break
          end

          Chef::Log.debug("Waiting for all cluster nodes to set #{mark} to #{revision}...")
          sleep(5)
        end # while true
      end # Timeout
    rescue Timeout::Error
      remaining = cluster_nodes - nodes_with_mark_set
      if fatal
        message = \
          "Some cluster nodes didn't set #{mark} to #{revision}: " +
          remaining.join(" ") +
          ". Please check chef-client logs for remaining nodes."
        Chef::Log.fatal(message)
        raise message
      else
        message = \
          "Some cluster nodes didn't set #{mark} to #{revision}: " +
          remaining.join(" ") +
          ". Going on..."
        Chef::Log.warn(message)
      end
    end
  end
end
