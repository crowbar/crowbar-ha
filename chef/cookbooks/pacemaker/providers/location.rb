# Author:: Robert Choi
# Cookbook Name:: pacemaker
# Provider:: location
#
# Copyright:: 2013, Robert Choi
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

this_dir = ::File.dirname(__FILE__)
require ::File.expand_path("../libraries/pacemaker", this_dir)
require ::File.expand_path("../libraries/chef/mixin/pacemaker", this_dir)

include Chef::Mixin::Pacemaker::StandardCIBObject

action :create do
  name = new_resource.name

  if @current_resource_definition.nil?
    create_resource(name)
  else
    maybe_modify_resource(name)
  end
end

action :update do
  standard_update_action
end

action :delete do
  next unless @current_resource
  standard_delete_resource
end

def cib_object_class
  ::Pacemaker::Constraint::Location
end

def load_current_resource
  standard_load_current_resource
end

def resource_attrs
  [:rsc, :score, :lnode]
end

def create_resource(name)
  standard_create_resource
end

def maybe_modify_resource(name)
  standard_maybe_modify_resource(name)
end
