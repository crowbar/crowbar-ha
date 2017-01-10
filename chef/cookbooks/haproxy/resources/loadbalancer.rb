#
# 2009-2013, Opscode, Inc
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

# This is largely copied/inspired from https://github.com/hw-cookbooks/haproxy

actions :create, :delete
default_action :create

attribute :name,    kind_of: String,  name_attribute: true
attribute :type,    kind_of: String,  default: "listen", equal_to: ["listen", "backend", "frontend"]
attribute :address, kind_of: String,  default: "0.0.0.0"
attribute :port,    kind_of: Integer, default: 0
attribute :mode,    kind_of: String,  default: "http", equal_to: ["http", "tcp", "health"]
attribute :balance, kind_of: String,  default: "", equal_to: ["", "roundrobin", "static-rr", "leastconn", "first", "source"]
attribute :use_ssl, kind_of: [TrueClass, FalseClass], default: false
attribute :options, kind_of: Array,   default: []
attribute :servers, kind_of: Array,   default: []
