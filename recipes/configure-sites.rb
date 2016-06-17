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

  # If the node is one this site belongs to, set it up on the box.
  if fullSite['servers'] and fullSite['servers'].include? node.name

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

      # Setup user & database.
      databasePassword = fullSite['database_password'] || random_password
      databaseUser = fullSite['database_username'] || siteName
      databaseName = fullSite['database_name'] || siteName

      mysql_database_user databaseUser do
        connection connection_info
        password databasePassword
        action :create
      end

      puts "USER DATABASE PASSWORD #{databasePassword}" #DEBUG

      # Grant access to database.
      mysql_database_user siteName do
        connection connection_info
        password databasePassword
        database_name databaseName
        action :grant
      end

      # Create a directory for shared data for releases.
      directory "/var/www/vhosts/#{siteName}/shared/" do
        owner 'www'
        group 'staff'
        mode '0775'
        action :create
      end

      # Write config file for app.
      if fullSite['type'] == 'madison'
        template "/var/www/vhosts/#{siteName}/shared/.env" do
          action :create_if_missing
          source 'site/madison/.env.erb'
          owner 'www'
          group 'staff'
          mode '0664'
          variables fullSite.to_hash
        end
      elsif fullSite['type'] == 'wordpress'
        template "/var/www/vhosts/#{siteName}/shared/wp-config.php" do
          action :create_if_missing
          source 'site/madison/wp-config.php.erb'
          owner 'www'
          group 'staff'
          mode '0664'
          variables fullSite.to_hash
        end
      end

    end
  end
end
