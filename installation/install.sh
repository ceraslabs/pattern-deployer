#!/bin/sh

# exit the shell script if error
set -e

if [ ! -f /usr/bin/chef-client ]; then
  sudo apt-get update
  sudo apt-get install -y ruby ruby-dev libopenssl-ruby rdoc ri irb build-essential wget ssl-cert curl

  # install rubygems from source
  cd /tmp
  curl -O http://production.cf.rubygems.org/rubygems/rubygems-1.8.10.tgz
  tar zxf rubygems-1.8.10.tgz
  cd rubygems-1.8.10
  sudo ruby setup.rb --no-format-executable
fi

#sudo gem update --no-rdoc --no-ri
sudo gem install ohai --no-rdoc --no-ri --verbose

# install Chef 10
sudo gem install chef --no-rdoc --no-ri --verbose -v "~>10.18"

# create solo.rb
cat >/tmp/solo.rb <<EOL
file_cache_path "/tmp/chef-solo"
cookbook_path "/tmp/chef-solo/cookbooks"
EOL

# get external ip address
my_ip=`curl -m 5 -s http://169.254.169.254/latest/meta-data/public-ipv4`
if [ "$my_ip" ]; then
  my_ip_valid=`echo "${my_ip}." | grep -E "([0-9]{1,3}\.){4}"`
fi

if [ ! "$my_ip_valid" ]; then
  echo "can't get external ip-address from meta-data, try to get it from ifconfig.me"
  my_ip=`curl -m 5 -s ifconfig.me`
  if [ "$my_ip" ]; then
     my_ip_valid=`echo "${my_ip}." | grep -E "([0-9]{1,3}\.){4}"`
  fi
fi

if [ ! "$my_ip_valid" ]; then
  echo "can't get external ip-address, use localhost instead"
  my_ip=localhost
fi

# create chef.json
chef_server_url="http://$my_ip:4000"
cat >/tmp/chef.json <<EOL
{
  "chef_server": {
    "server_url": "$chef_server_url",
    "webui_enabled": true
  },
  "run_list": [ "recipe[chef-server::rubygems-install]" ]
}
EOL

# run chef-solo to install chef-server
sudo chef-solo -c /tmp/solo.rb -j /tmp/chef.json -r http://s3.amazonaws.com/chef-solo/bootstrap-latest.tar.gz

# declare chef related variables
new_client_name=workstation
new_client_key_path=$HOME/.chef/$new_client_name.pem
validation_key_path=/etc/chef/validation.pem

# copy validation key
mkdir -p ~/.chef
sudo cp $validation_key_path ~/.chef/

# create an Chef API client if not before
if [ ! -f $new_client_key_path ]
then
  sudo knife configure -i -y --defaults -u $new_client_name -k $new_client_key_path -s $chef_server_url -r ''
fi

# grant permission to current user
user=$USER
sudo chown -R $user:$user ~/.chef/

# install the MySQL database and other neccessary dependencies
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y mysql-server mysql-client libmysqlclient-dev \
                                                       git-core libcurl4-openssl-dev libxslt-dev libxml2-dev

# create MySQL user account
mysql -u root -e "CREATE USER 'pattern-deployer'@'localhost' IDENTIFIED BY 'pattern-deployer';" || true
mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO 'pattern-deployer'@'localhost';FLUSH PRIVILEGES;"

# clone source
cd
git clone git://github.com/ceraslabs/pattern-deployer.git

# setup the project
cd pattern-deployer
sudo ruby setup.rb production -d --as-user $user \
                --db-user pattern-deployer \
                --db-password pattern-deployer \
                --chef-client-name $new_client_name \
                --chef-client-key $new_client_key_path \
                --chef-server $chef_server_url

# start the application
sudo bundle exec passenger start -p 80 -e production -d --user=$user