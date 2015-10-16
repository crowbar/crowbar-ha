#
# Copyright 2015, SUSE
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

# The goal of this resource is to make it possible to define ordering
# constraints on a set of resources, while some of the resources exist in a
# deployment, but not necessarily in this pacemaker cluster: we do not want to
# include resources that do not exist in this cluster when creating the
# ordering constraint.
#
# Example (using the default provider we ship):
#
# crowbar_pacemaker_order_only_existing "o-mywebapp" do
#  score "Mandatory"
#  ordering ["database", "apache", "mywebapp"]
#  action :create
# end
#
# If at least two resources among ["database", "apache", "mywebapp"] exist in
# this HA cluster, then an ordering constraint will be created.  If there's one
# resource that is not in this HA cluster, then it will be skipped. For
# instance, if the database lives elsewhere, this resource will be equivalent
# to:
#
# pacemaker_order "o-mywebapp" do
#  score "Mandatory"
#  ordering "apache mywebapp"
#  action :create
# end
#

actions :create, :delete

default_action :create

attribute :name,     kind_of: String, name_attribute: true
attribute :score,    kind_of: String
attribute :ordering, kind_of: [Array, String]
