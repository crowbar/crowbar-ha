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

# See resource definition for how to use this LWRP.

def delete_order(name)
  pacemaker_order "#{name}-only-existing" do
    name   name
    action :nothing
  end.run_action(:delete)
end

action :create do
  # evil command line; there must be a better way to fetch the list of resources
  # unfortunately, "crm_resource --list-raw" doesn't list groups/clones/etc.
  all_resources = %x{crm --display=plain configure show | awk '/^(primitive|group|clone|ms)/ {print $2}'}.split("\n")
  ordering_for_existing_resources = new_resource.ordering.select { |r| all_resources.include?(r) }

  if ordering_for_existing_resources.length <= 1
    delete_order(new_resource.name)
  else
    pacemaker_order "#{new_resource.name}-only-existing" do
      name     new_resource.name
      score    new_resource.score
      ordering ordering_for_existing_resources.join(" ")
      action   :nothing
    end.run_action(:create)
  end
end

action :delete do
  delete_order(new_resource.name)
end
