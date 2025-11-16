# Class: roles::base
#
# Install and Configure a Nagios server
#
class roles::nagios inherits roles::base {
  include profiles::nagios
  include profiles::nagios::nrpe
  include profiles::consul
  include profiles::consul::consul_template

  Class['profiles::consul'] -> Class['profiles::consul::consul_template']
}
