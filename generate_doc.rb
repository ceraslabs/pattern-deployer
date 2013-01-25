#!/usr/bin/ruby
#
# Copyright 2013 Marin Litoiu, Hongbin Lu, Mark Shtern, Bradlley Simmons, Mike
# Smit
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

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