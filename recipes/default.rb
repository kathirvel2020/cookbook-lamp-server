#
# Cookbook Name:: lamp-server
# Recipe:: default
#

# Setup webserver.

include_recipe 'base-server::default'
include_recipe 'lamp-server::install-database'
include_recipe 'lamp-server::install-webserver'
include_recipe 'lamp-server::configure-sites'
