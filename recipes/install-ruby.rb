# We need a newer ruby.
node.default['rvm']['install_rubies'] = 'true'
node.default['rvm']['rubies'] = ['2.3.0']
node.default['rvm']['default_ruby'] = '2.3.0'

include_recipe 'rvm::system_install'
include_recipe 'rvm::default'
include_recipe 'rvm::system'

# Also include ruby for the deploy user, needed for build process
node.default['rvm']['user_installs'] = [
  {
    'user' => 'deploy',
    'install_rubies' => 'true',
    'rubies' => ['2.3.0'],
    'default_ruby' => '2.3.0'
  }
]

# We use the mysql2_chef_gem to create databases later.
mysql2_chef_gem 'default' do
  provider Chef::Provider::Mysql2ChefGem::Mariadb
  action :install
end

# We need to fix json-jwt to an old version for letsencrypt.
#
chef_gem 'json-jwt' do
  version '1.5.2'
end
