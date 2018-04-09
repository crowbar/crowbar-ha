#
# Copyright 2016, SUSE LINUX GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Api
  class Pacemaker < Tableless
    class << self
      # Check for presence of HA setup, which is a requirement for non-disruptive upgrade
      def ha_presence_check
        unless repocheck["ha"]["available"]
          return { errors: [I18n.t("api.pacemaker.ha_not_installed")] }
        end
        members = Node.find("pacemaker_config_environment:*")
        members.empty? ? { errors: [I18n.t("api.pacemaker.ha_not_configured")] } : {}
      end

      # Simple check if HA clusters report some problems
      # If there are no problems, empty hash is returned.
      # If this fails, information about failed actions for each cluster founder is
      # returned in a hash that looks like this:
      # {
      #     "crm_failures" => {
      #             "node1" => "reason for crm status failure"
      #     },
      #     "failed_actions" => {
      #             "node2" => "Failed action on this node"
      #     }
      # }
      # User has to manually clean pacemaker resources before proceeding with the upgrade.
      def health_report
        ret = {}
        crm_failures = {}
        failed_actions = {}

        # get unique list of founder names across all clusters
        cluster_founders_names = Node.find(
          "run_list_map:pacemaker-cluster-member"
        ).map! do |node|
          node[:pacemaker][:founder]
        end.uniq
        founders = cluster_founders_names.map { |name| Node.find_by_name(name) }
        return ret if founders.empty?

        service_object = CrowbarService.new(Rails.logger)
        service_object.check_if_nodes_are_available founders

        founders.each do |n|
          ssh_retval = n.run_ssh_cmd("crm status 2>&1")
          if (ssh_retval[:exit_code]).nonzero?
            crm_failures[n.name] = "#{n.name}: #{ssh_retval[:stdout]}"
            crm_failures[n.name] << " #{ssh_retval[:stderr]}" unless ssh_retval[:stderr].blank?
            next
          end
          ssh_retval = n.run_ssh_cmd('crm status | grep -A 2 "^Failed Actions:"')
          if (ssh_retval[:exit_code]).zero?
            failed_actions[n.name] = "#{n.name}: #{ssh_retval[:stdout]}"
            failed_actions[n.name] << " #{ssh_retval[:stderr]}" unless ssh_retval[:stderr].blank?
          end
        end
        ret["crm_failures"] = crm_failures unless crm_failures.empty?
        ret["failed_actions"] = failed_actions unless failed_actions.empty?
        ret
      end

      def set_node_as_founder(name)
        # 1. find the cluster new founder is in
        new_founder = NodeObject.find_node_by_name(name)
        if new_founder.nil?
          Rails.logger.error("Node #{name} not found!")
          return false
        end
        unless new_founder[:pacemaker]
          Rails.logger.error("Node #{name} does not have pacemaker setup")
          return false
        end
        if new_founder[:pacemaker][:founder] == new_founder[:fqdn]
          Rails.logger.debug("Node #{name} is already the cluster founder.")
        end

        # 2. find the role for this cluster and change the founder
        cluster_env = new_founder[:pacemaker][:config][:environment]
        cluster_role = RoleObject.find_role_by_name(cluster_env)

        cluster_role.default_attributes["pacemaker"]["founder"] = new_founder[:fqdn]
        cluster_role.save

        # 3. change drdb master in all nodes from this cluster
        ::Node.find("pacemaker_config_environment:#{cluster_env}").each do |node|
          # we need to set the new founder on the cluster nodes anyway. This is because
          # even if we have the new founder on the role, that will only be applied to the
          # node during a chef run, but could lead to issues on node searches before that chef-run
          # so for peace of mind, we update it on all nodes always.
          node["pacemaker"]["founder"] = new_founder[:fqdn]
          if node[:drbd] && node[:drbd][:rsc]
            node[:drbd][:rsc].each_key do |res|
              # if this is the new founder set master to true, false if its any other node
              node[:drbd][:rsc][res][:master] = (node[:fqdn] == new_founder[:fqdn])
            end
          end
          node.save
        end
      end

      def repocheck
        Api::Node.repocheck(addon: "ha")
      end
    end
  end
end
