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
include_recipe 'apache2::mod_php5'
include_recipe 'apache2::mod_ssl'
