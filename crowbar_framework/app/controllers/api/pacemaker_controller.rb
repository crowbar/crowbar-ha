#
# Copyright 2016, SUSE Linux GmbH
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

module Api
  class PacemakerController < ApiController
    api :GET, "/api/pacemaker/health", "Health check for pacemaker clusters"
    api_version "2.0"
    def health
      render json: {
        clusters_health: Api::Pacemaker.health_report
      }
    end

    api :GET, "/api/pacemaker/repocheck", "Sanity check ha repositories"
    api_version "2.0"
    def repocheck
      render json: {}, status: :not_implemented
    end
  end
end
