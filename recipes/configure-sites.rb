include_recipe 'chef-vault::default'

# Create a list of the users. Apparently you can't just iterate over the data
# bag's contents directly.
sites = data_bag('sites').select do |key|
  !key.end_with?('_keys')
end

apacheOwner = 'deploy'
apacheGroup = 'staff'

# Make a directory for vhosts
directory "/var/www/vhosts" do
  owner  apacheOwner
  group  apacheGroup
  mode   '0775'
  action :create
end

sites.each do |siteName|
  # Get the users' real data from the vault.
  fullSite = chef_vault_item('sites', siteName)

  # Make a directory for the site
  directory "/var/www/vhosts/#{siteName}" do
    owner  apacheOwner
    group  apacheGroup
    mode   '0775'
    action :create
  end

  siteTemplate = 'apache/standard.conf.erb'
  if 'madison' == fullSite['type']
    siteTemplate = 'apache/madison.conf.erb'
  end

  web_app siteName do
    server_name fullSite['url']
    docroot     "/var/www/vhosts/#{siteName}"
    template    siteTemplate
  end

end
