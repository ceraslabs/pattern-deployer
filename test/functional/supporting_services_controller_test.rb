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

