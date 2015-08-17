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

require "chef/shell_out"

module DrbdOverview
  def self.get(resource)
    cmd = "drbd-overview"
    output = Chef::ShellOut.new(cmd).run_command.stdout

    resource_output = ""
    output.split("\n").each do |line|
      if line =~ /^ *[0-9]+:#{resource}[\/ ]/
        resource_output = line
        break
      end
    end

    Chef::Log.info "DRBD status of #{resource}: #{resource_output}"

    if resource_output.empty?
      nil
    else
      # Example:
      # ["0:postgresql/0", "Connected", "Primary/Secondary", "UpToDate/Diskless", "C", "r----- /var/lib/pgsql xfs 4.0G 67M 4.0G 2%"]
      parsed = resource_output.split(" ", 6)
      item_1, item_2 = parsed[2].split("/", 2)
      state_1, state_2 = parsed[3].split("/", 2)

      overview = {}
      overview["state"] = parsed[1]

      overview["primary"] = nil
      if item_1 == "Primary"
        overview["primary"] = state_1
      elsif item_2 == "Primary"
        overview["primary"] = state_2
      end

      overview["secondary"] = nil
      if item_1 == "Secondary"
        overview["secondary"] = state_1
      elsif item_2 == "Secondary"
        overview["secondary"] = state_2
      end

      overview
    end
  end
end
