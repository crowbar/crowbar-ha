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

class Api::ClustersController < ApiController
  api :GET, "/api/clusters", "List all HA clusters"
  api_version "2.0"
  def index
    render json: [], status: :not_implemented
  end

  api :GET, "/api/clusters/:id", "Show a single HA cluster"
  api_version "2.0"
  param :id, Integer, desc: "Cluster ID", required: true
  def show
    render json: {}, status: :not_implemented
  end

  api :GET, "/api/clusters/health", "Health check HA clusters"
  api_version "2.0"
  def health
    render json: {}, status: :not_implemented
  end

  api :GET, "/api/clusters/repocheck", "Sanity check ha repositories"
  api_version "2.0"
  def repocheck
    render json: {}, status: :not_implemented
  end
end
