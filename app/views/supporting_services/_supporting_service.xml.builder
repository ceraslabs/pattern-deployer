xml.supporting_service do
  xml.name service.name
  xml.available service.available?
  xml.state service.get_status
  xml.error service.get_error if service.get_error
  xml.additional_message service.get_msg if service.get_msg
end