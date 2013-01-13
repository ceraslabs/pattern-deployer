require 'test_helper'

class DocControllerTest < ActionController::TestCase

  include Devise::TestHelpers

  def setup
    @user = users(:user1)
    sign_in @user
  end

  def teardown
    sign_out :user
  end

  test "doc valid" do
    success = system "source2swagger -i '#{Rails.root}/app/controllers' -e 'rb' -c '##~' -o /tmp"
    assert success, $?
  end
end
