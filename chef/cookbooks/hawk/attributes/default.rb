# Copyright 2013, Dell, Inc., Inc.
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

default[:hawk][:platform][:packages] = %w(hawk hawk-templates)

# Currently hardcoded in /srv/www/hawk/config/lighttp.conf and
# /srv/www/hawk/app/views/dashboard/index.html.erb but added
# here so that the barclamp web UI can build the correct hyperlink.
default[:hawk][:server][:port] = 7630
