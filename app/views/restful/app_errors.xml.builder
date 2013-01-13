xml.response do
  xml.status "failed"
  xml.error do
    xml.error_type exception.error_type
    xml.error_message exception.message

    trace = exception.backtrace.to_s
    inner_ex = exception.get_inner_exception
    if inner_ex
      trace += "\nCaused by:\n"
      trace += inner_ex.backtrace.join("\n")
    end
    xml.trace trace if not trace.empty?
  end
end