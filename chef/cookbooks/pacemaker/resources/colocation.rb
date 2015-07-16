# Author:: Robert Choi
# Cookbook Name:: pacemaker
# Resource:: colocation
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

actions :create, :delete

default_action :create

attribute :name, :kind_of => String, :name_attribute => true
attribute :score, :kind_of => String

# If more than two resources are given, Pacemaker will treat this as a
# resource set.  Originally this was an Array, but then we added
# support for it alternatively being a String, in order to support
# parentheses in the constraints passed to Pacemaker.  (Parentheses
# allow sub-groups of resources which can be started in parallel.)  We
# have kept Arrays for backwards compatibility, but they are
# deprecated, because it's better if the responsibility of
# understanding the structure of this part of the crm configure string
# is delegated to Pacemaker.
attribute :resources, :kind_of => [Array, String]
