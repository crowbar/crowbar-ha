#
# 2014, SUSE
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

action :create do
  modules_loaded = {}

  node['drbd']['rsc'].keys.sort.each do |resource_name|
    resource = node['drbd']['rsc'][resource_name]

    # make sure that we can mount the drbd ASAP, by making sure the kernel
    # module (if there's one) is loaded
    if %w(xfs).include?(resource["fstype"]) && !modules_loaded[resource["fstype"]]
      mod = resource["fstype"]

      if node.platform == 'suse'
        execute "Enable #{mod} module on load (/etc/sysconfig/kernel)" do
          command "sed -i 's/^\\(MODULES_LOADED_ON_BOOT=\"[^\"]*\\)\"/\\1 #{mod}\"/' /etc/sysconfig/kernel"
          not_if "grep -q '^MODULES_LOADED_ON_BOOT=\"[^\"]*#{mod}[^\"]*\"' /etc/sysconfig/kernel"
          action :nothing
        end.run_action(:run)
      end

      execute "modprobe #{mod}" do
        action :nothing
      end.run_action(:run)

      modules_loaded[resource["fstype"]] = true

      package "xfsprogs" do
        action :nothing
      end.run_action(:install)
    end

    next if resource["configured"]

    lvm_logical_volume resource_name do
      group new_resource.lvm_group
      size  resource["lvm_size"]
      action :nothing
    end.run_action(:create)

    drbd_resource resource_name do
      remote_host resource["remote_host"]
      port resource["port"]
      disk "/dev/#{new_resource.lvm_group}/#{resource["lvm_lv"]}"
      device resource["device"]
      fstype resource["fstype"]
      master resource["master"]
      action :nothing
    end.run_action(:create)

    node['drbd']['rsc'][resource_name]['configured'] = true
    node.save
  end
end
