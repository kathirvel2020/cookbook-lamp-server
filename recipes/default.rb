#
# Cookbook Name:: lamp-server
# Recipe:: default
#

# Setup webserver.

include_recipe 'base-server::default'
include_recipe 'lamp-server::install-database'
include_recipe 'lamp-server::install-ruby'
include_recipe 'lamp-server::install-webserver'
include_recipe 'lamp-server::install-php'
include_recipe 'lamp-server::install-node'
include_recipe 'lamp-server::install-mail'
include_recipe 'lamp-server::configure-sites'
