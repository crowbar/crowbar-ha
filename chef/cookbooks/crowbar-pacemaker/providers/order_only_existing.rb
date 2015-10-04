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
    name name
    action :nothing
  end.run_action(:delete)
end

action :create do
  ordering = new_resource.ordering
  # evil command line; there must be a better way to fetch the list of resources
  # unfortunately, "crm_resource --list-raw" doesn't list groups/clones/etc.
  all_resources = %x{crm --display=plain configure show | awk '/^(primitive|group|clone|ms)/ {print $2}'}.split("\n")
  case ordering
  when Array
    ordering_for_existing_resources = ordering.select { |r| all_resources.include?(r) }
  when String
    # Try to ensure the syntax makes sense
    raise "Sets in ordering cannot be nested." if ordering =~ /\([^\)]*[\(\[\]]/ || ordering =~ /\[[^\]]*[\[\(\)]/
    # Only keep valid items, including what's valid in the crm syntax, which
    # is:
    # - foo ( bar foobar ) xyz
    # - foo [ bar foobar ] xyz
    # - foo [ bar foobar sequantial=true ] xyz
    # - foo [ bar foobar require-all=true ] xyz
    ordering_array = ordering.split(" ")
    existing_ordering_array = ordering_array.select do |r|
      all_resources.include?(r) || %w{( ) [ ]}.include?(r) || r =~ /sequential=/ || r =~ /require-all=/
    end
    # Drop empty sets; we don't want something like:
    #  order Mandatory: foo ( ) bar
    # It should become:
    #  order Mandatory: foo bar
    existing_ordering = existing_ordering_array.join(" ").gsub(/[\(\[](( sequential=[^ ]*)|( require-all=[^ ]*))* [\)\]]/, "")
    ordering_for_existing_resources = existing_ordering.split(" ")
  end

  if ordering_for_existing_resources.length <= 1
    delete_order(new_resource.name)
  else
    pacemaker_order "#{new_resource.name}-only-existing" do
      name new_resource.name
      score new_resource.score
      ordering ordering_for_existing_resources.join(" ")
      action :nothing
    end.run_action(:create)
  end
end

action :delete do
  delete_order(new_resource.name)
end
