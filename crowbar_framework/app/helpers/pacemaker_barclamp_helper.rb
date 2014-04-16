# Copyright 2014, SUSE LINUX Products GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#  http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: Dell Crowbar Team
# Author: SUSE LINUX Products GmbH
#

module PacemakerBarclampHelper
  def node_aliases
    Hash[nodes_hash.map { |n| [n.first, { :alias => n.last[:alias] }] }]
  end

  def no_quorum_policy_for_pacemaker(selected)
    # no translation for the strings as we simply show the values that will end
    # up in the config file
    options_for_select(
      [
        ["ignore", "ignore"],
        ["freeze", "freeze"],
        ["stop", "stop"],
        ["suicide", "suicide"]
      ],
      selected.to_s
    )
  end

  def stonith_mode_for_pacemaker(selected)
    options_for_select(
      [
        [t(".stonith_modes.manual"), "manual"],
        [t(".stonith_modes.ipmi_barclamp"), "ipmi_barclamp"],
        [t(".stonith_modes.sbd"), "sbd"],
        [t(".stonith_modes.shared"), "shared"],
        [t(".stonith_modes.per_node"), "per_node"],
        [t(".stonith_modes.libvirt"), "libvirt"]
      ],
      selected.to_s
    )
  end
end
