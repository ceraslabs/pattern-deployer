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
require 'test_helper'

class SupportingServicesControllerTest < ActionController::TestCase

  include Devise::TestHelpers
  include RestfulHelper

  def setup
    @user = users(:user1)
    sign_in @user
    @openvpn_id = 1
    @dns_id = 2
    @host_protection_id = 3
  end

  def teardown
    sign_out :user
  end

  test "can access" do
    post :show, :id => @dns_id
    assert_response :success, @response.body

    # test get the created topology
    post :show, :id => @openvpn_id
    assert_response(:success)

    # test get the created topology
    post :show, :id => @host_protection_id
    assert_response(:success)

    # test index the created topology
    post :index
    assert_response(:success)
    assert_have_values get_response_elements("//supporting_service/name"), ["openvpn", "dns", "host_protection"]
  end

  test "unknown operation" do
    post :update, :id => 1, :operation => "unknown"
    assert_response(:bad_request)
    assert_select "error_type", "ParametersValidationError"
  end

  test "anyone have permission" do
    sign_out :user
    sign_in users(:user2)

    post :show, :id => @dns_id
    assert_response :success

    # test get the created topology
    post :show, :id => @openvpn_id
    assert_response(:success)

    # test get the created topology
    post :show, :id => @host_protection_id
    assert_response(:success)

    # test index the created topology
    post :index
    assert_response(:success)
    assert_have_values get_response_elements("//supporting_service/name"), ["openvpn", "dns", "host_protection"]
  end
end