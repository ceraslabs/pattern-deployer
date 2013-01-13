class Ec2Credential < Credential

  alias_attribute :access_key_id, :aws_access_key_id
  alias_attribute :secret_access_key, :aws_secret_access_key

  attr_accessible :aws_access_key_id, :aws_secret_access_key, :access_key_id, :secret_access_key

  validates :aws_access_key_id, :presence => true
  validates :aws_secret_access_key, :presence => true
end
