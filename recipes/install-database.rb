# Configure MariaDB.

node.default['mariadb']['use_default_repository'] = true

# Enable these to overwrite the existing root password.
# node.default['mariadb']['allow_root_pass_change'] = true

include_recipe 'ca-certificates::default'

include_recipe 'mariadb::default'
include_recipe 'mariadb::client'

root_db_password = random_password
node.default['mariadb']['server_root_password'] = root_db_password
node.default['mariadb']['client']['development_files'] = true

template '/root/.my.cnf' do
  # Change the action to :create to overwrite the root password.
  action :create_if_missing
  source 'mariadb/.my.cnf.erb'
  owner 'root'
  group 'root'
  mode '0600'
end

# We use the mysql2_chef_gem to create databases later.

# We need ruby first.
node.default['rvm']['install_rubies'] = 'true'
node.default['rvm']['rubies'] = ['2.3.0']
node.default['rvm']['default_ruby'] = '2.3.0'

include_recipe 'rvm::default'
include_recipe 'rvm::system'

mysql2_chef_gem 'default' do
  provider Chef::Provider::Mysql2ChefGem::Mariadb
  action :install
end
