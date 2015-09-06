name             "pacemaker"
maintainer       "Crowbar Project"
maintainer_email "crowbar@dell.com"
license          "Apache 2.0"
description      "Installs/configures Pacemaker"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.1.1"

depends "corosync"
depends "yum"

%w{ redhat centos suse }.each do |os|
  supports os
end
