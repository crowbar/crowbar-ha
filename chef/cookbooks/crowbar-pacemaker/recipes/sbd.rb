#
# Cookbook Name:: crowbar-pacemaker
# Recipe:: sbd
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

sbd_devices = nil
sbd_devices ||= (node[:pacemaker][:stonith][:sbd][:nodes][node[:fqdn]][:devices] rescue nil)
sbd_devices ||= (node[:pacemaker][:stonith][:sbd][:nodes][node[:hostname]][:devices] rescue nil)

sbd_devices.each do |sbd_device|
  if File.symlink?(sbd_device)
    sbd_device_simple = File.expand_path(File.readlink(sbd_device), File.dirname(sbd_device))
  else
    sbd_device_simple = sbd_device
  end
  disks = BarclampLibrary::Barclamp::Inventory::Disk.all(node).select { |d| d.name == sbd_device_simple }
  disk = disks.first
  if disk.nil?
    # This is not a disk; let's see if this is a partition and deal with it
    sbd_sys_dir = "/sys/class/block/#{File.basename(sbd_device_simple)}"
    if File.exists?("#{sbd_sys_dir}/partition") && File.symlink?(sbd_sys_dir)
      sbd_sys_dir_full = File.expand_path(File.readlink(sbd_sys_dir), File.dirname(sbd_sys_dir))
      # sbd_sys_dir_full is something like
      # "/sys/devices/platform/host3/session2/target3:0:0/3:0:0:0/block/sda/sda1",
      # and we want to get the "sda" part of this
      parent_sys_dir_full = sbd_sys_dir_full[1..sbd_sys_dir_full.rindex("/")-1]
      parent_disk = "/dev/#{File.basename(parent_sys_dir_full)}"
      disks = BarclampLibrary::Barclamp::Inventory::Disk.all(node).select { |d| d.name == parent_disk }
      disk = disks.first
    end
  end
  if disk.nil?
    raise "Cannot find device #{sbd_device}!"
  end
  if disk.claimed? && disk.owner != "sbd"
    raise "Cannot use #{sbd_device} for SBD: it was claimed for #{disk.owner}!"
  end
  unless disk.claim("sbd")
    raise "Cannot claim #{sbd_device} for SBD!"
  end
end
