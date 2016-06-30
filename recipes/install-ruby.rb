include_recipe 'rvm::system_install'
include_recipe 'rvm::default'
include_recipe 'rvm::system'

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
