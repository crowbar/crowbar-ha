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

require "timeout"

action :create do
  name        = new_resource.name
  remote_host = new_resource.remote_host
  port        = new_resource.port
  disk        = new_resource.disk
  device      = new_resource.device
  fstype      = new_resource.fstype
  master      = new_resource.master
  mount       = new_resource.mount

  raise "No remote host defined for drbd resource #{name}!" if remote_host.nil?
  remote_nodes = search(:node, "name:#{remote_host}")
  raise "Remote node #{remote_host} not found!" if remote_nodes.empty?
  remote = remote_nodes.first

  drbd_resource_template = template "/etc/drbd.d/#{name}.res" do
    cookbook "drbd"
    source "resource.erb"
    variables(
      resource: name,
      device: device,
      disk: disk,
      local_hostname: node.hostname,
      local_ip: node.ipaddress,
      port: port,
      remote_hostname: remote.hostname,
      remote_ip: remote.ipaddress
    )
    owner "root"
    group "root"
    action :nothing
  end
  drbd_resource_template.run_action(:create)

  # first pass only, initialize drbd
  # for disks re-usage from old resources we will run with force option
  p = execute "drbdadm -- --force create-md #{name}" do
    only_if { drbd_resource_template.updated_by_last_action? }
    action :nothing
  end
  p.run_action(:run)

  drbdadm_up = execute "drbdadm up #{name}" do
    only_if { drbd_resource_template.updated_by_last_action? }
    action :nothing
  end
  drbdadm_up.run_action(:run)

  # claim primary based off of master
  execute "drbdadm -- --overwrite-data-of-peer primary #{name}" do
    only_if { drbd_resource_template.updated_by_last_action? && master }
    action :nothing
  end.run_action(:run)

  # you may now create a filesystem on the device, use it as a raw block device
  # for disks re-usage from old resources we will run with force option
  execute "mkfs -t #{fstype} -f #{device}" do
    only_if { drbd_resource_template.updated_by_last_action? && master }
    action :nothing
  end.run_action(:run)

  unless mount.nil? or mount.empty?
    directory mount do
      action :nothing
    end.run_action(:create)

    #mount -t xfs -o rw /dev/drbd0 /shared
    mount mount do
      device device
      fstype fstype
      only_if { master }
      action :nothing
    end.run_action(:mount)
  end
end

action :wait do
  name = new_resource.name
  begin
    Timeout.timeout(20) do
      while true
        overview = DrbdOverview.get(name)
        break if !overview.nil? && [overview["primary"], overview["secondary"]].include?("UpToDate")
        sleep 2
      end
    end # Timeout
  rescue Timeout::Error
    raise "DRBD resource #{name} not ready!"
  end
end
