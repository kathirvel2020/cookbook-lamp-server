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

include_recipe 'apache2'
include_recipe 'apache2::mod_rewrite'
include_recipe 'apache2::mod_php5'
include_recipe 'apache2::mod_ssl'
include_recipe 'apache2::mod_version'

# Disable threaded mpm
apache_module 'mpm_prefork'
apache_module 'mpm_event' do
  enable false
end

# For RHEL remove the mpm prefork load because apache does this automatically
# for us, and the load file references a .so module that doesn't exist.
# TODO: You might need to do this for SUSE also.

case node['platform_family']
when 'rhel', 'fedora'
	load_file = '/etc/httpd/mods-enabled/mpm_prefork.load'

	link load_file do
		action :delete
		notifies :restart, 'service[apache2]', :immediately
	end
end
