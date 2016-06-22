# Install Apache

# We create a default staff group that all users belong to. We use this group
# for apache as well, so we can edit files written by the  webserver.
#
# This is also done by our users cookbook.
group 'staff' do
  action :create
end

# We need a cross-platform consistent user for Apache/Nginx.
user 'www' do
  comment 'Web User'
  group 'staff'
  manage_home false
  system true
end

node.default['apache']['user'] = 'www'
node.default['apache']['group'] = 'staff'

include_recipe 'apache2'
include_recipe 'apache2::mod_rewrite'
include_recipe 'apache2::mod_ssl'

# Install PHP
node.default['php']['version'] = '5.6.22'
node.default['php']['install_method'] = 'source'
node.default['php']['checksum'] = '4ce0f58c3842332c4e3bb2ec1c936c6817294273abaa37ea0ef7ca2a68cf9b21'

include_recipe 'php'

# Install Node
node.default['nodejs']['version'] = '4.4.5'
node.default['nodejs']['install_method'] = 'binary' # or source

# Checksums from https://nodejs.org/dist/v4.4.5/SHASUMS256.txt
node.default['nodejs']['source']['checksum'] = 'ea9c96ae4768feee4f18a26b819b9b4f6e49105ea0ee8c5c9d188dc8d49d4b77'
node.default['nodejs']['binary']['checksum'] = '15d57c4a3696df8d5ef1bba452d38e5d27fc3c963760eeb218533c48381e89d5'
include_recipe 'nodejs'
