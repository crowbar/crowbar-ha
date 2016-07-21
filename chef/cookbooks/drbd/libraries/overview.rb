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
    cmd = "drbd-overview --color=no"
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
      # Examples:
      # "0:postgresql/0  Connected(2*) Primar/Second UpToDa/Incons"
      # "0:postgresql/0  Connected(2*) Primar/Second UpToDa/UpToDa /var/lib/pgsql    xfs 5.0G 94M 4.9G 2%"
      parsed = resource_output.split " "
      item_1, item_2 = parsed[2].split("/", 2)
      state_1, state_2 = parsed[3].split("/", 2)

      # Example: "0:postgresql/0  Connected(2*) Primar/Second UpToDate(2*)"
      state_2 = state_1 if state_2.nil? && state_1.include?("2*")
      # Example: "1:rabbitmq/0    Connected(2*) Secondary(2*) Incons/Incons"
      item_2 = item_1 if item_2.nil? && item_1.include?("2*")

      overview = {}
      overview["state"] = parsed[1]

      overview["primary"] = nil
      if item_1.include? "Primar"
        overview["primary"] = state_1
      elsif item_2.include? "Primar"
        overview["primary"] = state_2
      end

      overview["secondary"] = nil
      if item_1.include? "Second"
        overview["secondary"] = state_1
      elsif item_2.include? "Second"
        overview["secondary"] = state_2
      end

      overview
    end
  end
end
