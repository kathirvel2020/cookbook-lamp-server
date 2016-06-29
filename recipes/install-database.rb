# Configure MariaDB.

node.default['mariadb']['use_default_repository'] = true

# Enable these to overwrite the existing root password.
# node.default['mariadb']['allow_root_pass_change'] = true

include_recipe 'ca-certificates::default'

root_db_password = random_password
node.default['mariadb']['server_root_password'] = root_db_password
node.default['mariadb']['client']['development_files'] = true

include_recipe 'mariadb::default'
include_recipe 'mariadb::client'

template '/root/.my.cnf' do
  # Change the action to :create to overwrite the root password.
  action :create_if_missing
  source 'mariadb/.my.cnf.erb'
  owner 'root'
  group 'root'
  mode '0600'
end
