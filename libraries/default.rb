# Helpers

def random_password
  require 'securerandom'
  SecureRandom.base64
end
