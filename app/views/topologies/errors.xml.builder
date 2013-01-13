xml.response do
  xml.status "failed"
  xml.error do
    xml.error_type @error_type
    xml.error_message @error_message
  end
end
