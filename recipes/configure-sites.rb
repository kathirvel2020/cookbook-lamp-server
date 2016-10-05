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
  begin
    Chef::EncryptedDataBagItem.load_secret
  rescue
    full_site = Chef::DataBagItem.load('sites', site_name)
  else
    full_site = Chef::EncryptedDataBagItem.load('sites', site_name).to_hash
  end

  # If the node is one this site belongs to, set it up on the box.
  if full_site['servers'] and full_site['servers'].include? node.name

    # Apache setup.

    # Make a directory for the site.
    directory "/var/www/vhosts/#{site_name}" do
      owner apache_owner
      group apache_group
      mode '0775'
      action :create
    end

    # Setup some config values.
    uses_rollback = full_site['type'] == 'madison' || full_site['uses_rollback']

    # If the site uses rollback, we have a releases directory.
    if uses_rollback
      directory "/var/www/vhosts/#{site_name}/releases" do
        owner apache_owner
        group apache_group
        mode '0775'
        action :create
      end

      # TODO: The code for this `init` folder causes some issues with capistrano
      # release cleanup. It doesn't appear to be necessary on Ubuntu 14.04, but
      # might be an issue on other OS's. Leaving it commented out for now.

      #directory "/var/www/vhosts/#{site_name}/releases/init" do
      #  owner apache_owner
      #  group apache_group
      #  mode '0775'
      #  action :create
      #end

      #if full_site['type'] == 'madison'
      #  directory "/var/www/vhosts/#{site_name}/releases/init/client/build" do
      #    owner apache_owner
      #    group apache_group
      #    mode '0775'
      #    recursive true
      #    action :create
      #  end
      #end

      directory "/var/www/vhosts/#{site_name}/shared" do
        owner apache_owner
        group apache_group
        mode '0775'
        action :create
      end

      # Create a temporary folder for the current realease if there isn't one
      # already. Apache won't start if the webroot references a missing folder.
      #link "/var/www/vhosts/#{site_name}/current" do
      #  to "/var/www/vhosts/#{site_name}/releases/init"
      #  not_if "test -L /var/www/vhosts/#{site_name}/current"
      #end
    end

    # Our deployment path changes to add releases if we have rollback.
    if !full_site['deploy_path']
      if uses_rollback
        full_site['deploy_path'] = "/var/www/vhosts/#{site_name}/current"
        full_site['shared_path'] = "/var/www/vhosts/#{site_name}/shared"
      else
        full_site['deploy_path'] = "/var/www/vhosts/#{site_name}"
        full_site['shared_path'] = "/var/www/vhosts/#{site_name}"
      end
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
      ssl full_site['ssl']
      docroot "/var/www/vhosts/#{site_name}"
      template site_template
    end

    # MySQL setup.

    # Setup user & database.
    database_password = full_site['database_password'] || random_password
    database_user = full_site['database_username'] || site_name
    database_name = full_site['database_name'] || site_name

    # mysql2_chef_gem should have been installed in the install-database step.
    mysql_database database_name do
      connection connection_info
      action :create
    end

    mysql_database_user database_user do
      connection connection_info
      password database_password
      action :create
    end

    # Grant access to database.
    mysql_database_user site_name do
      connection connection_info
      username database_user
      password database_password
      database_name database_name
      action :grant
    end

    # Write config file for app.
    if full_site['type'] == 'madison'
      directory "#{full_site['shared_path']}/server" do
        owner 'www'
        group 'staff'
        mode '0775'
        action :create
      end

      template "#{full_site['shared_path']}/server/.env" do
        action :create_if_missing
        source 'site/madison/.env.erb'
        owner 'www'
        group 'staff'
        mode '0664'
        variables :params => full_site.to_hash
      end

      # Also include supervisor and it's config file
      include_recipe 'supervisor::default'

      supervisor_service "#{site_name}-laravel-worker" do
        action :enable
        autostart true
        process_name '%(program_name)s_%(process_num)02d'
        command "php #{full_site['deploy_path']}/server/artisan queue:listen --sleep=3 --tries=3"
        autostart true
        autorestart true
        user 'deploy'
        numprocs 8
        redirect_stderr true
        stdout_logfile "/var/log/supervisor/#{site_name}-laravel-worker.log"
      end

    elsif full_site['type'] == 'wordpress'
      # This was taken from the Wordpress cookbook.  Unfortunately, that
      # cookbook wants to do other things for us that we don't want, so we
      # do this manually instead.
      ::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)
      node.set_unless['wordpress']['keys']['auth'] = secure_password
      node.set_unless['wordpress']['keys']['secure_auth'] = secure_password
      node.set_unless['wordpress']['keys']['logged_in'] = secure_password
      node.set_unless['wordpress']['keys']['nonce'] = secure_password
      node.set_unless['wordpress']['salt']['auth'] = secure_password
      node.set_unless['wordpress']['salt']['secure_auth'] = secure_password
      node.set_unless['wordpress']['salt']['logged_in'] = secure_password
      node.set_unless['wordpress']['salt']['nonce'] = secure_password
      node.save unless Chef::Config[:solo]

      template "#{full_site['shared_path']}/wp-config.php" do
        action :create_if_missing
        source 'site/wordpress/wp-config.php.erb'
        owner 'www'
        group 'staff'
        mode '0664'
        variables(
          :db_name           => database_name,
          :db_user           => database_user,
          :db_password       => database_password,
          :db_host           => node['wordpress']['db']['host'],
          :db_prefix         => node['wordpress']['db']['prefix'],
          :db_charset        => node['wordpress']['db']['charset'],
          :db_collate        => node['wordpress']['db']['collate'],
          :auth_key          => node['wordpress']['keys']['auth'],
          :secure_auth_key   => node['wordpress']['keys']['secure_auth'],
          :logged_in_key     => node['wordpress']['keys']['logged_in'],
          :nonce_key         => node['wordpress']['keys']['nonce'],
          :auth_salt         => node['wordpress']['salt']['auth'],
          :secure_auth_salt  => node['wordpress']['salt']['secure_auth'],
          :logged_in_salt    => node['wordpress']['salt']['logged_in'],
          :nonce_salt        => node['wordpress']['salt']['nonce'],
          :lang              => node['wordpress']['languages']['lang'],
          :allow_multisite   => node['wordpress']['allow_multisite'],
          :wp_config_options => node['wordpress']['wp_config_options']
        )
      end
    end

    # SSL Certificate setup.
    # TODO : Test this on live.

    if full_site['ssl']

      # DEBUG staging endpoint
      # node.default['letsencrypt']['endpoint'] = 'https://acme-v01.api.letsencrypt.org'

      node.default['letsencrypt']['contact'] = "mailto:#{full_site['admin_email']}"

      include_recipe 'letsencrypt::default'

      directory "/var/www/vhosts/#{site_name}/letsencrypt" do
        owner apache_owner
        group apache_group
        recursive true
        mode '0775'
        action :create
      end

      letsencrypt_selfsigned full_site['url'] do
        crt "/etc/ssl/#{full_site['url']}.crt"
        key "/etc/ssl/#{full_site['url']}.key"
        chain "/etc/ssl/#{full_site['url']}.pem"
        owner apache_owner
        group apache_group
        notifies :restart, 'service[apache2]', :immediate
        not_if do
          ::File.exists?("/etc/ssl/#{full_site['url']}.crt")
        end
      end

      # Add Let's Encrypt Certs.
      letsencrypt_certificate full_site['url'] do
        crt "/etc/ssl/#{full_site['url']}.crt"
        key "/etc/ssl/#{full_site['url']}.key"
        chain "/etc/ssl/#{full_site['url']}.pem"
        method 'http'
        owner apache_owner
        group apache_group
        #alt_names ["www.#{full_site['url']}"]
        wwwroot "/var/www/vhosts/#{site_name}/letsencrypt"
        notifies :restart, 'service[apache2]', :immediate
      end

    end

  end
end
