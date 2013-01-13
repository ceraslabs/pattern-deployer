require 'test_helper'

class SupportingServiceTest < ActiveSupport::TestCase

  def setup
    @user = users(:user1)
  end

  test "initialization" do
    assert_no_difference("SupportingService.count") do
      SupportingService.initialize_db @user
    end

    supporting_services(:openvpn).destroy
    supporting_services(:dns).destroy
    supporting_services(:host_protection).destroy
    assert_no_difference("SupportingService.count", 3) do
      SupportingService.initialize_db @user
    end

    SupportingService.all.each do |service|
      assert SupportingService.list_of_services.include?(service.name)
      assert service.get_state == State::UNDEPLOY
    end
  end

  test "permission" do
    service = supporting_services(:openvpn)

    # resource owner has all permission
    user = users(:user1)
    ability = Ability.new(user)
    assert ability.can?(:show, service)
    assert ability.can?(:update, service)

    # normal user other than owner don't have permission
    user = users(:user2)
    ability = Ability.new(user)
    assert ability.can?(:show, service)
    assert ability.cannot?(:update, service)

    # admin has all permission regardless resource owner
    user = users(:admin)
    ability = Ability.new(user)
    assert ability.can?(:show, service)
    assert ability.can?(:update, service)
  end
end
