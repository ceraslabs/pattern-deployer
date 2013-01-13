require 'test_helper'

class ApiControllerTest < ActionController::TestCase

  include Devise::TestHelpers

  def setup
    sign_in users(:user1)
  end

  def teardown
    sign_out :user
  end

  test "should get index" do
    get :index
    assert_response :success
  end

end
