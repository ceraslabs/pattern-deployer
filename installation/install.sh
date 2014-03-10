#!/bin/sh

# exit the shell script if error
set -e

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ruby1.9.3 build-essential wget ssl-cert curl \
                                                       mysql-server mysql-client libmysqlclient-dev \
                                                       git-core libcurl4-openssl-dev libxslt-dev libxml2-dev

# install rubygems from source
cd /tmp
curl -O http://production.cf.rubygems.org/rubygems/rubygems-2.2.2.tgz
tar zxf rubygems-2.2.2.tgz
cd rubygems-2.2.2
sudo ruby setup.rb --no-format-executable

# install Chef Server
curl -L https://www.opscode.com/chef/install.sh | sudo bash -s -- -P server
sudo chef-server-ctl reconfigure

# get external ip address
my_ip=`curl -m 5 -s http://169.254.169.254/latest/meta-data/public-ipv4` && true
if [ "$my_ip" ]; then
  my_ip_valid=`echo "${my_ip}." | grep -E "([0-9]{1,3}\.){4}"`
fi

my_ip=`curl -m 5 -s http://169.254.169.254/latest/meta-data/local-ipv4` && true
if [ "$my_ip" ]; then
  echo "can't get public IP address from meta-data, try private IP instead"
  my_ip_valid=`echo "${my_ip}." | grep -E "([0-9]{1,3}\.){4}"`
fi

if [ ! "$my_ip_valid" ]; then
  echo "can't get any ip-address from meta-data, try to get it from ifconfig.me"
  my_ip=`curl -m 5 -s ifconfig.me` && true
  if [ "$my_ip" ]; then
     my_ip_valid=`echo "${my_ip}." | grep -E "([0-9]{1,3}\.){4}"`
  fi
fi

if [ ! "$my_ip_valid" ]; then
  echo "can't get external ip-address, use localhost instead"
  my_ip=localhost
fi

# reconfigure Chef Server
chef_server_url="http://$my_ip:4000"
echo "
nginx['enable_non_ssl'] = true
nginx['non_ssl_port'] = 4000
nginx['url'] = '${chef_server_url}'
" | sudo tee /etc/chef-server/chef-server.rb >/dev/null
sudo chef-server-ctl reconfigure

# create MySQL user account
db_user=pattern-deployer
db_password=pattern-deployer
mysql -u root -e "CREATE USER '${db_user}'@'localhost' IDENTIFIED BY '${db_password}';" || true
mysql -u root -e "GRANT ALL PRIVILEGES ON *.* TO '${db_user}'@'localhost';FLUSH PRIVILEGES;"

# clone source
cd
git clone git://github.com/ceraslabs/pattern-deployer.git

# setup the project
cd pattern-deployer
user=$USER
sudo ruby setup.rb production -d --as-user $user \
                --db-user $db_user \
                --db-password $db_password \
                --chef-server $chef_server_url

# start the application
sudo bundle exec passenger start -p 80 -e production -d --user=$user --max-pool-size=3 --min-instances=3