require 'test_helper'

class CredentialTest < ActiveSupport::TestCase

  def setup
    @user = users(:user1)
    @ec2_attrs = {:credential_id => "ec2_test", :for_cloud => "ec2", :owner => @user, :access_key_id => "test", :secret_access_key => "test"}
    @openstack_attrs = {:credential_id => "openstack_test", :for_cloud => "openstack", :owner => @user, :username => "test_user", :password => "test_pwd", :tenant => "test_tenant", :endpoint => "test_endpoint"}
  end

  test "base credential" do
    # verify presence of attributes
    attrs = @ec2_attrs.dup
    attrs.delete(:owner)
    attrs.delete(:credential_id)
    attrs.delete(:for_cloud)
    credential = Ec2Credential.create attrs
    assert_equal credential.errors.size, 3, "Unexpected number of errors"
    assert credential.errors[:owner].any?, "No error message when owner not present"
    assert credential.errors[:credential_id].any?, "No error message when credential_id not present"
    assert credential.errors[:for_cloud].any?, "No error message when for_cloud not present"

    # verify credential is not saved with duplicated id
    test_attr = {:credential_id => "other"}
    credential = Ec2Credential.create @ec2_attrs.merge(test_attr)
    assert_equal credential.errors.size, 1, "Unexpected number of errors"
    assert credential.errors[:credential_id].any?, "Error is not on the right attribute"

    # verify cloud must be supported
    test_attr = {:for_cloud => "not_supported_cloud"}
    credential = Ec2Credential.create @ec2_attrs.merge(test_attr)
    assert_equal credential.errors.size, 1, "Unexpected number of errors: #{credential.errors.full_messages}"
    assert credential.errors[:for_cloud].any?, "Error is not on the right attribute"
  end

  test "ec2 credential" do
    # verify content of ec2 credential must be presented
    attrs = @ec2_attrs.dup
    attrs.delete(:access_key_id)
    attrs.delete(:secret_access_key)
    credential = Ec2Credential.create(attrs)
    assert_equal credential.errors.size, 2, "Unexpected number of errors"
    assert credential.errors[:aws_access_key_id].any?, "No error message when access_key_id not present"
    assert credential.errors[:aws_secret_access_key].any?, "No error message when secret_access_key not present"

    # verify valid ec2 credential will be created successfully
    credential = Ec2Credential.create(@ec2_attrs)
    assert credential.valid?, "valid ec2 credential is not created"
    credential.destroy
  end

  test "openstack credential" do
    # verify content of credential must be presented
    attrs = @openstack_attrs.dup
    attrs.delete(:username)
    attrs.delete(:password)
    attrs.delete(:tenant)
    attrs.delete(:endpoint)
    credential = OpenstackCredential.create(attrs)
    assert_equal credential.errors.size, 4, "Unexpected number of errors: #{credential.errors.full_messages}"
    assert credential.errors[:openstack_username].any?, "No error message when username not present"
    assert credential.errors[:openstack_password].any?, "No error message when password not present"
    assert credential.errors[:openstack_tenant].any?, "No error message when tenant not present"
    assert credential.errors[:openstack_endpoint].any?, "No error message when endpoint not present"

    # verify valid openstack credential will be created successfully
    credential = OpenstackCredential.create(@openstack_attrs)
    assert credential.valid?, "valid openstack credential is not created"
    credential.destroy  
  end

  test "permission" do
    credential = credentials(:ec2)

    # resource owner has all permission
    user = users(:user1)
    ability = Ability.new(user)
    assert ability.can?(:show, credential)
    assert ability.can?(:create, credential)
    assert ability.can?(:destroy, credential)
    assert ability.can?(:update, credential)

    # normal user other than owner don't have permission
    user = users(:user2)
    ability = Ability.new(user)
    assert ability.cannot?(:show, credential)
    assert ability.cannot?(:create, credential)
    assert ability.cannot?(:destroy, credential)
    assert ability.cannot?(:update, credential)

    # admin has all permission regardless resource owner
    user = users(:admin)
    ability = Ability.new(user)
    assert ability.can?(:show, credential)
    assert ability.can?(:create, credential)
    assert ability.can?(:destroy, credential)
    assert ability.can?(:update, credential)
  end
end
