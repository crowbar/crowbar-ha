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

actions :create, :wait
default_action :wait

# we cannot use mark as the name attribute because we generally will have two
# resources: one for wait and one for create. However, we detect some magic
# names: if the mark is not set and the name is "wait-XYZ" or "create-XYZ",
# then "XYZ" will be used as the mark
attribute :name,      :kind_of => String,  :name_attribute => true

# see comment above for magic that can be used for the name to skip this
# paramater
attribute :mark,      :kind_of => String,  :default => nil

# this is optional in crowbar; the barclamp proposal revision will be used
attribute :revision,  :kind_of => Integer, :default => nil

attribute :fatal,     :kind_of => [TrueClass, FalseClass], :default => false
attribute :timeout,   :kind_of => Integer, :default => 60
