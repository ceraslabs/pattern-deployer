object @exception
attribute :message => :error_message
node :trace do |e|
  e.backtrace.join("\n") if e.backtrace
end
node :error_type do |e|
  e.respond_to?(:error_type) ? e.error_type : e.class.name
end