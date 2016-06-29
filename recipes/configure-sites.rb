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

apache_owner = 'deploy'
apache_group = 'staff'

# Make a directory for vhosts.
directory "/var/www/vhosts" do
  owner apache_owner
  group apache_group
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

sites.each do |site_name|
  # Get the users' real data from the vault.
  full_site = chef_vault_item('sites', site_name)

  # If the node is one this site belongs to, set it up on the box.
  if full_site['servers'] and full_site['servers'].include? node.name

    # Apache setup. All sites get Apache.

    # Make a directory for the site.
    directory "/var/www/vhosts/#{site_name}" do
      owner apache_owner
      group apache_group
      mode '0775'
      action :create
    end

    templateExists = has_source?("apache/#{full_site['type']}.conf.erb",
      :templates, 'lamp-server')

    if templateExists
      site_template = "apache/#{full_site['type']}.conf.erb"
      puts "Apache Template: Using #{full_site['type']}"
    else
      site_template = 'apache/standard.conf.erb'
      puts "Apache Template: Using default"
    end

    web_app site_name do
      server_name full_site['url']
      server_aliases full_site['aliases']
      docroot "/var/www/vhosts/#{site_name}"
      template site_template
    end

    # MySQL setup. Not all sites get MySQL.

    # Setup database.
    if ['madison', 'wordpress'].include? full_site['type']
      # mysql2_chef_gem should have been installed in the install-database step.
      mysql_database site_name do
        connection connection_info
        action :create
      end

      # Setup user & database.
      database_password = full_site['database_password'] || random_password
      database_user = full_site['database_username'] || site_name
      database_name = full_site['database_name'] || site_name

      mysql_database_user database_user do
        connection connection_info
        password database_password
        action :create
      end

      # Grant access to database.
      mysql_database_user site_name do
        connection connection_info
        password database_password
        database_name database_name
        action :grant
      end

      # Create a directory for shared data for releases.
      directory "/var/www/vhosts/#{site_name}/shared/" do
        owner 'www'
        group 'staff'
        mode '0775'
        action :create
      end

      # Write config file for app.
      if full_site['type'] == 'madison'
        directory "/var/www/vhosts/#{site_name}/shared/server" do
          owner 'www'
          group 'staff'
          mode '0775'
          action :create
        end

        template "/var/www/vhosts/#{site_name}/shared/server/.env" do
          action :create_if_missing
          source 'site/madison/.env.erb'
          owner 'www'
          group 'staff'
          mode '0664'
          variables :params => full_site.to_hash
        end
      elsif full_site['type'] == 'wordpress'
        template "/var/www/vhosts/#{site_name}/shared/wp-config.php" do
          action :create_if_missing
          source 'site/madison/wp-config.php.erb'
          owner 'www'
          group 'staff'
          mode '0664'
          variables :params => full_site.to_hash
        end
      end

    end
  end
end
