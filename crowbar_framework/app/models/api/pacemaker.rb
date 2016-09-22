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
    end
  end
end
