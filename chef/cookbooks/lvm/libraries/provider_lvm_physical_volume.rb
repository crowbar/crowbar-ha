#
# Cookbook Name:: lvm
# Library:: provider_lvm_physical_volume
#
# Copyright 2009-2013, Opscode, Inc.
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

require 'chef/provider'
require 'chef/mixin/shell_out'
require 'pathname'

class Chef
  class Provider
    # The provider for lvm_physical_volume resource
    #
    class LvmPhysicalVolume < Chef::Provider
      include Chef::Mixin::ShellOut
      # Loads the current resource attributes
      #
      # @return [Chef::Resource::LvmPhysicalVolume] the lvm_physical_volume resource
      #
      def load_current_resource
        @current_resource ||= Chef::Resource::LvmPhysicalVolume.new(@new_resource.name)
        @current_resource
      end

      # The create action
      #
      def action_create
        physical_volumes = []
        cmd = shell_out('pvdisplay')
        cmd.error!
        cmd.stdout.split("\n").each do |line|
          args = line.split()
          if args[0] == 'PV' and args[1] == 'Name'
            physical_volumes << Pathname.new(args[2]).realpath.to_s
          end
        end
        if physical_volumes.include?(Pathname.new(new_resource.name).realpath.to_s)
          Chef::Log.info "Physical volume '#{new_resource.name}' found. Not creating..."
        else
          Chef::Log.info "Creating physical volume '#{new_resource.name}'"
          cmd = shell_out("pvcreate #{new_resource.name}")
          cmd.error!
          new_resource.updated_by_last_action(true)
        end
      end
    end
  end
end
