# We need a newer ruby.
default['rvm']['install_rubies'] = 'true'
default['rvm']['rubies'] = ['2.3.0']
default['rvm']['default_ruby'] = '2.3.0'

# Gems used by the server and for compiling assets.
default['rvm']['global_gems'] = [
  {
    'name' => 'bundler',
    'version' => '1.12.5'

  },
  {
    'name' => 'sass',
    'version' => '3.4.21'

  },
  {
    'name' => 'compass',
    'version' => '1.0.3'

  }
]
