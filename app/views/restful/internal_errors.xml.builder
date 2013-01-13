xml.response do
  xml.status "failed"
  xml.error do
    xml.error_type "UnexpectedError"
    xml.error_message exception.message
    xml.trace exception.backtrace.join("\n")
  end
end