#!/usr/bin/ruby

require "fileutils"
require 'json'


# generate api docs from comment
api_dir = "app/views/api_docs"
FileUtils.mkdir_p(api_dir)
command = "source2swagger -i app/controllers -e 'rb' -c '##~' -o #{api_dir} >/dev/null"
unless system command
  unless system "bundle exec #{command}"
    raise "Failed to generate doc with command #{command}"
  end
end

# add .erb suffix to file names
Dir.new(api_dir).each do |file_name|
  next unless file_name.match(/\.json$/)

  new_file_name = file_name.sub(/\.json$/, ".json.erb")
  Dir.chdir(api_dir) do
    File.open(file_name, "r") do |fin|
      File.open(new_file_name, "w") do |fout|
        json = fin.read
        fout.write(JSON.pretty_generate(JSON.parse(json)))
      end
    end
    FileUtils.rm(file_name)
  end
end

# collect the list of APIs
apis = Array.new
Dir.foreach(api_dir) do |file_name|
  next if file_name == "." || file_name == ".." || file_name == "index.json.erb"
  api_name = file_name.sub(/\.json.erb$/, "")
  apis << %Q[{"path":"/api_docs/#{api_name}", "description":"#{api_name}"}]
end

json = <<-JSONTEXT
  {
    "apiVersion":"0.2",
    "swaggerVersion":"1.1",
    "basePath":"<%= request.protocol + request.host_with_port %>",
    "apis":[
      #{apis.join(",\n")}
    ]
  }
JSONTEXT

File.open("app/views/api_docs/index.json.erb", "w") do |out|
  out.write(JSON.pretty_generate(JSON.parse(json)))
end
