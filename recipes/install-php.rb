package "php-pear" do
  action :install
end

# Install PHP
node.default['php']['packages'].push('php5-mcrypt')
node.default['php']['packages'].push('php5-mysql')
node.default['php']['packages'].push('php5-curl')

package 'php5-mcrypt'
package 'php5-mysql'
package 'php5-curl'

include_recipe 'php'
