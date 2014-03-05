object @exception
attribute :message => :error_message
node :trace do |ex|
  ex.backtrace.join("\n") if ex.backtrace
end
node :error_type do |ex|
  ex.class.name
end