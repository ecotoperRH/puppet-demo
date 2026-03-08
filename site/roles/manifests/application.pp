# Class: roles::application
#
# Inherit configurations from roles::base and install configurations for an app server
#
class roles::application inherits roles::base {
  include profiles::nagios::nrpe
  include profiles::consul
  include profiles::release
}
