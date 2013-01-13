#!/usr/bin/ruby

require "fileutils"

def change_url(file_path, url)
  lines = IO.readlines(file_path).map do |line|
    line.sub(/localhost/, url)
  end
  File.open(file_path, 'w') do |file|
    file.puts lines
  end
end


# generate api docs from comment
api_dir = "public/api-docs"
system "source2swagger -i app/controllers -e 'rb' -c '##~' -o #{api_dir}"
Dir.new(api_dir).each do |file_name|
  if file_name.match(/\.json$/)
    # get rid of tailing .json in filename
    file_path = "#{api_dir}/#{file_name}"
    file_name.sub!(/\.json$/, "")
    FileUtils.mv file_path, "#{api_dir}/#{file_name}"
  end
end

# get url
hostname = `curl http://169.254.169.254/latest/meta-data/public-hostname`
raise "cannot get host name" if hostname.nil? || hostname.empty?
url = "http://" + hostname

# replace localhost with public url
files = Array.new
Dir.new(api_dir).each do |file_name|
  if file_name != "." && file_name != ".."
    file_path = "#{api_dir}/#{file_name}"
    change_url(file_path, url)
    files << file_name
  end
end

# generate api-docs.json
apis = files.map do |file_name|
  "{\"path\":\"/api-docs/#{file_name}\", \"description\":\"#{file_name}\"}"
end
json = <<-eos
  {
    "apiVersion":"0.2",
    "swaggerVersion":"1.1",
    "basePath":"#{url}",
    "apis":[
      #{apis.join(",\n")}
    ]
  }
eos
api_docs_file = "public/api-docs.json"
File.open(api_docs_file, "w") do |out|
  out.write(json)
end

=begin
# prepare production database
success = system "rake db:create db:schema:load RAILS_ENV=production"
unless success
  raise "Failed to prepare production database: " + $?.to_s
end
=end

=begin
# precompile asset
success = system "rake assets:precompile RAILS_ENV=production"
unless success
  raise "Failed to precompile asset: " + $?.to_s
end

# start the server
success = system "rails server -e production -p 80 -d"
unless success
  raise "Failed to start rails server: " + $?.to_s
end
=end
