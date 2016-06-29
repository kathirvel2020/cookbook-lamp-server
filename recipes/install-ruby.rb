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

# Gems used by the Chef ruby instance.

# We need to fix json-jwt to an old version for letsencrypt.
chef_gems = {
  'json-jwt' =>'1.5.2'
}

chef_gems.each do |name, version|
  chef_gem name do
    version version
  end
end

# Gems used by the rest of the server.
server_gems = {
  'bundler' => '1.12.5',
  'sass' => '3.4.21',
  'compass' => '1.0.3'
}

server_gems.each do |name, version|
  gem_package name do
    version version
  end
end
