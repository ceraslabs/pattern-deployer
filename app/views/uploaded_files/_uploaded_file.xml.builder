xml.uploaded_file do
  xml.file_type file.get_file_type
  xml.file_name file.file_name
  xml.key_pair_id file.key_pair_id if file.key_pair_id
  xml.for_cloud file.for_cloud if file.for_cloud
end