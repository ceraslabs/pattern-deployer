#
# Copyright 2013 Marin Litoiu, Hongbin Lu, Mark Shtern, Bradlley Simmons, Mike
# Smit
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
class ApiController < RestfulController

  skip_load_and_authorize_resource

  ##
  # Show a list of resources
  #
  # @url [GET] /api
  # 
  # @example_response
  # TODO
  def index
    @supporting_services = get_resources_readable_by_me(SupportingService.all)
    @topologies = get_resources_readable_by_me(Topology.all)
    @uploaded_files = get_resources_readable_by_me(UploadedFile.all)
    @credentials = get_resources_readable_by_me(Credential.all)
    render :formats => "json"
  end
end