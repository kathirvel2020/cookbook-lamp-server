include_recipe 'chef-vault::default'
chef_gem 'chef-helpers' do
  compile_time true
end
require 'chef-helpers'

# Create a list of the users. Apparently you can't just iterate over the data
# bag's contents directly.
sites = data_bag('sites').select do |key|
  !key.end_with?('_keys')
end

# sites = ['chicago'] #DEBUG

apacheOwner = 'deploy'
apacheGroup = 'staff'

# Make a directory for vhosts.
directory "/var/www/vhosts" do
  owner apacheOwner
  group apacheGroup
  mode '0775'
  action :create
end

connection_info = {
  :host => '127.0.0.1',
  :username => 'root',
}

# Read our root database password.
ruby_block 'get_database_password' do
  only_if { File.exist?('/root/.my.cnf') }
  block do
    f = File.open('/root/.my.cnf', 'r')
    f.each_line do |line|
      line.match(/^password=(.*)$/) {|m|
        node.default['mariadb']['server_root_password'] = m[1]
        break;
      }
    end

    connection_info[:password] = node.default['mariadb']['server_root_password']
  end
end

sites.each do |siteName|
  # Get the users' real data from the vault.
  fullSite = chef_vault_item('sites', siteName)

  # fullSite = { #DEBUG
  #   'database-name' => 'chicago',
  #   'database-password' => 'ogjvNJ8KBZ4e',
  #   'database-username' => 'chicago',
  #   'dev-url' => 'devchicago.mymadison.io',
  #   'id' => 'madison-chicago',
  #   'name' =>  'Madison Chicago',
  #   'shortname' => 'chicago',
  #   'url' => 'chicago.mymadison.io',
  #   'type' => 'madison',
  #   'servers' => ['Madison-Dev-1','default-ubuntu-1404']
  # }

  # If the node is one this site belongs to, set it up on the box.
  if fullSite['servers'].include? node.name

    # Apache setup. All sites get Apache.

    # Make a directory for the site.
    directory "/var/www/vhosts/#{siteName}" do
      owner apacheOwner
      group apacheGroup
      mode '0775'
      action :create
    end

    templateExists = has_source?("apache/#{fullSite['type']}.conf.erb",
      :templates, 'lamp-server')

    if templateExists
      siteTemplate = "apache/#{fullSite['type']}.conf.erb"
      puts "Apache Template: Using #{fullSite['type']}"
    else
      siteTemplate = 'apache/standard.conf.erb'
      puts "Apache Template: Using default"
    end

    web_app siteName do
      server_name fullSite['url']
      server_aliases fullSite['aliases']
      docroot "/var/www/vhosts/#{siteName}"
      template siteTemplate
    end

    # MySQL setup. Not all sites get MySQL.

    # Setup database.
    if ['madison', 'wordpress'].include? fullSite['type']
      # mysql2_chef_gem should have been installed in the install-database step.
      mysql_database siteName do
        connection connection_info
        action :create
      end

      # Setup user.
      databasePassword = random_password

      mysql_database_user siteName do
        connection connection_info
        password databasePassword
        action :create
      end

      # puts "USER DATABASE PASSWORD #{databasePassword}" #DEBUG

      # Grant access to database.
      mysql_database_user siteName do
        connection connection_info
        password databasePassword
        database_name siteName
        action :grant
      end

      # TODO Write config file for app.
    end

  end

end
