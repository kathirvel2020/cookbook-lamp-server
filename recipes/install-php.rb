# Install PHP
node.default['php']['version'] = '5.6.22'
node.default['php']['install_method'] = 'source'
node.default['php']['checksum'] = '4ce0f58c3842332c4e3bb2ec1c936c6817294273abaa37ea0ef7ca2a68cf9b21'

puts "PHP Packages"
puts node.default['php']['packages'].push('php5-mcrypt')

include_recipe 'php'
