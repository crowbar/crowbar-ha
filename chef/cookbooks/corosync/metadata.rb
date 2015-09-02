name             "corosync"
maintainer       "SUSE, GmbH"
license          "Apache 2.0"
description      "Installs and configures a base corosync installation"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "1.1.1"

depends "yum"
depends "yum-epel", '<= 0.6.0'

%w{ redhat centos suse }.each do |os|
  supports os
end
