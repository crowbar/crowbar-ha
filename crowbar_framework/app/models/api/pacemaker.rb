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
        founders = NodeObject.find("pacemaker_founder:true AND pacemaker_config_environment:*")
        founders.empty? ? { errors: [I18n.t("api.pacemaker.ha_not_configured")] } : {}
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

        founders = NodeObject.find("pacemaker_founder:true AND pacemaker_config_environment:*")
        return ret if founders.empty?

        service_object = CrowbarService.new(Rails.logger)
        service_object.check_if_nodes_are_available founders

        founders.each do |n|
          ssh_retval = n.run_ssh_cmd("crm status 2>&1")
          if (ssh_retval[:exit_code]).nonzero?
            crm_failures[n.name] = ssh_retval[:stdout]
            next
          end
          ssh_retval = n.run_ssh_cmd('crm status | grep -A 2 "^Failed Actions:"')
          if (ssh_retval[:exit_code]).zero?
            failed_actions[n.name] = ssh_retval[:stdout]
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
        if new_founder[:pacemaker][:founder]
          Rails.logger.debug("Node #{name} is already the cluster founder.")
        end

        # 2. find the current cluster founder in the same cluster
        cluster_env = new_founder[:pacemaker][:config][:environment]
        old_founder = NodeObject.find(
          "pacemaker_founder:true AND pacemaker_config_environment:#{cluster_env}"
        ).first

        if old_founder.nil?
          Rails.logger.warning("No cluster founder found. Making #{name} the new founder anyway.")
        else
          old_founder[:pacemaker][:founder] = false
          if old_founder[:drbd] && old_founder[:drbd][:rsc]
            old_founder[:drbd][:rsc].each do |res, _|
              old_founder[:drbd][:rsc][res][:master] = false
            end
          end
          old_founder.save
        end

        # 3. mark given node as founder
        new_founder[:pacemaker][:founder] = true
        if new_founder[:drbd] && new_founder[:drbd][:rsc]
          new_founder[:drbd][:rsc].each do |res, _|
            new_founder[:drbd][:rsc][res][:master] = true
          end
        end
        new_founder.save
      end

      def repocheck
        Api::Node.repocheck(addon: "ha")
      end
    end
  end
end
