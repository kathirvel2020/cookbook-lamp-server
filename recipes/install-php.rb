package "php-pear" do
  action :install
end

include_recipe 'php::default'

# Add necessary PHP packages.
case node['platform_family']
when 'rhel', 'fedora'
  node.default['php']['packages'].push('php-mcrypt')
  node.default['php']['packages'].push('php-mysql')
  node.default['php']['packages'].push('php-curl')

when 'debian'
  node.default['php']['packages'].push('php5-mcrypt')
  node.default['php']['packages'].push('php5-mysql')
  node.default['php']['packages'].push('php5-curl')
end

include_recipe 'php::package'
