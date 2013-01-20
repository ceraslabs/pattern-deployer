#!/usr/bin/ruby

require "fileutils"

def replace_localhost_with_url_in_file(file_path, url)
  lines = IO.readlines(file_path).map do |line|
    line.sub(/localhost/, url)
  end
  File.open(file_path, 'w') do |file|
    file.puts lines
  end
end


# generate api docs from comment
api_dir = "public/api-docs"
FileUtils.mkdir_p(api_dir)
system "source2swagger -i app/controllers -e 'rb' -c '##~' -o #{api_dir}"
Dir.new(api_dir).each do |file_name|
  next unless file_name.match(/\.json$/)

  # get rid of tailing .json in filename
  new_file_name = file_name.sub(/\.json$/, "")
  Dir.chdir(api_dir) do
    FileUtils.mv(file_name, new_file_name)
  end
end

# get url
hostname = `curl http://169.254.169.254/latest/meta-data/public-hostname`.strip
raise "cannot get host name" if hostname.nil? || hostname.empty?
url = "http://" + hostname

# replace localhost with actual url
files = Array.new
Dir.foreach(api_dir) do |file_name|
  next if File.directory?(file_name) || file_name == "." || file_name == ".."

  file_path = "#{api_dir}/#{file_name}"
  replace_localhost_with_url_in_file(file_path, url)
  files << file_name
end

# generate api-docs.json
apis = files.map do |file_name|
  %Q[ {"path":"/api-docs/#{file_name}", "description":"#{file_name}"} ]
end

json = <<-JSONTEXT
  {
    "apiVersion":"0.2",
    "swaggerVersion":"1.1",
    "basePath":"#{url}",
    "apis":[
      #{apis.join(",\n")}
    ]
  }
JSONTEXT

File.open("public/api-docs.json", "w") do |out|
  out.write(json)
end
