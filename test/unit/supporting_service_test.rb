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