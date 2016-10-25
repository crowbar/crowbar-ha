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

      def repocheck
        Api::Node.repocheck(addon: "ha")
      end

      # Adapt DRBD information to possible changes of cluster founder
      def adapt_drbd_settings(founder_name)
        founder = NodeObject.find_node_by_name(founder_name)

        # nothing to be done if there's no DRBD setup
        return true unless founder[:drbd]

        modified = false
        founder[:drbd][:rsc].each do |_, resource|
          unless resource[:master]
            resource[:master] = true
            modified = true
          end
        end
        return true unless modified

        founder.save

        # adapt the info for remaining node
        cluster_env = founder[:pacemaker][:config][:environment]
        non_founder = NodeObject.find(
          "pacemaker_founder:false AND pacemaker_config_environment:#{cluster_env}"
        ).first
        non_founder[:drbd][:rsc].each do |_, resource|
          resource[:master] = false
        end
        non_founder.save
      end
    end
  end
end
