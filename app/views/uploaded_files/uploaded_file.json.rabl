attribute :id
attribute :file_name => :fileName
attribute :get_file_type => :fileType
attribute :for_cloud => :forCloud
attribute :key_pair_id => :keyPairId
node :link do |file|
  uploaded_file_path(file, :only_path => false)
end