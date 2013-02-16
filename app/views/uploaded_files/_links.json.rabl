attribute :file_name => :resource_name
node :resource_type do |file|
  file.class.name
end
node :link do |file|
  uploaded_file_path(file, :only_path => false)
end