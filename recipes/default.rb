#
# Cookbook Name:: lamp-server
# Recipe:: default
#

# Setup webserver.

def random_password
  require 'securerandom'
  SecureRandom.base64
end

# Apache.
include_recipe "apache2"
include_recipe "apache2::mod_rewrite"
include_recipe "apache2::mod_ssl"

# Configure MariaDB.

db_password = random_password

node.default['mariadb']['use_default_repository'] = true
node.default['mariadb']['server_root_password'] = db_password

# Enable these to overwrite the existing root password.
# node.default['mariadb']['allow_root_pass_change'] = true

include_recipe "mariadb::default"

template '/root/.my.cnf' do
  # Change the action to :create to overwrite the root password.
  action :create_if_missing
  source 'mariadb/.my.cnf.erb'
  owner  'root'
  group  'root'
  mode   '0600'
end
