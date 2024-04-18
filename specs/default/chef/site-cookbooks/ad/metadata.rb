name 'ad'
maintainer 's+c'
maintainer_email 'support@cyclecomputing.com'
license 'MIT'
description 'Installs/Configures AD integration'
long_description 'Installs/Configures AD integration'
version '1.0.0'
chef_version '>= 12.1' if respond_to?(:chef_version)

%w{ cvolume }.each {|c| depends c}
