class Credential < ActiveRecord::Base

  belongs_to :owner, :autosave => true, :class_name => "User", :foreign_key => "user_id", :inverse_of => :credentials

  attr_accessible :credential_id, :for_cloud, :owner, :id

  validates :credential_id, :presence => true, :uniqueness => true
  validates :for_cloud, :inclusion => { :in => Rails.configuration.supported_clouds, :message => "cloud %{value} is not supported" }
  validates_presence_of :owner
end
