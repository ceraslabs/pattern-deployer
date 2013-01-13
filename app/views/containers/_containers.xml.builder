containers.each do |container|
  xml << render("containers/container", :container => container)
end