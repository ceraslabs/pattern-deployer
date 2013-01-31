#!/bin/sh

# exit the shell script if error
set -e

# update apt-get
sudo apt-get update

# install ruby and the neccessary dependencies
sudo apt-get install -y ruby ruby-dev libopenssl-ruby rdoc ri irb build-essential wget ssl-cert curl

# install RubyGems
cd /tmp
curl -O http://production.cf.rubygems.org/rubygems/rubygems-1.8.10.tgz
tar zxf rubygems-1.8.10.tgz
cd rubygems-1.8.10
sudo ruby setup.rb --no-format-executable

# update gem
sudo gem update --no-rdoc --no-ri

# install chef
sudo gem install chef --no-rdoc --no-ri --verbose

# this is a walkaround to a bug(http://tickets.opscode.com/browse/CHEF-3721)
sudo gem install moneta --no-rdoc --no-ri --verbose -v "~> 0.6.0"
sudo gem uninstall moneta -v ">= 0.7.0"

# create solo.rb
cat >/tmp/solo.rb <<EOL
file_cache_path "/tmp/chef-solo"
cookbook_path "/tmp/chef-solo/cookbooks"
EOL

# create chef.json
cat >/tmp/chef.json <<EOL
{
  "chef_server": {
    "server_url": "http://localhost:4000",
    "webui_enabled": true
  },
  "run_list": [ "recipe[chef-server::rubygems-install]" ]
}
EOL

# run chef-solo to install chef-server
sudo chef-solo -c /tmp/solo.rb -j /tmp/chef.json -r http://s3.amazonaws.com/chef-solo/bootstrap-latest.tar.gz

mkdir -p ~/.chef
home=`echo ~`

# create an API client
new_client_name=workstation
new_client_key_path=$home/.chef/$new_client_name.pem
if [ ! -f $new_client_key_path ]
then
  sudo knife configure -i -y --defaults -u $new_client_name -k $new_client_key_path -r ''
fi

# read API client key
new_client_key=""
while read -r line
do
  if [ "$new_client_key" = "" ]
  then
    new_client_key=$line
  else
    new_client_key="$new_client_key\n$line"
  fi
done <$new_client_key_path

# read validation key
validation_key=""
while read -r line
do
  if [ "$validation_key" = "" ]
  then
    validation_key=$line
  else
    validation_key="$validation_key\n$line"
  fi
done </etc/chef/validation.pem

cwd=/tmp/pattern-deployer
rm -rf $cwd
mkdir $cwd
cd $cwd

# create file chef.json
cat >chef.json <<EOL
{
  "pattern_deployer": {
    "chef": {
      "api_client_name": "${new_client_name}",
      "api_client_key": "${new_client_key}",
      "validation_client_name": "chef-validator",
      "validation_key": "${validation_key}"
    }
  },
  "run_list": [ "recipe[pattern-deployer]" ]
}
EOL

curl -sL -o chef-repo.tgz https://github.com/ceraslabs/chef-repo/tarball/master
tar xvf chef-repo.tgz > tmp.txt
chef_repo=`head tmp.txt -n 1`
cd $chef_repo\cookbooks
ruby upload_all_cookbooks.rb

# run chef client
cd $cwd
sudo chef-client -j chef.json