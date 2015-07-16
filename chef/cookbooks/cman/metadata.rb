maintainer       "Rackspace US, Inc"
license          "Apache 2.0"
description      "Installs and configures a base CMAN installation"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "1.0.5"

%w{ ubuntu fedora }.each do |os|
  supports os
end
