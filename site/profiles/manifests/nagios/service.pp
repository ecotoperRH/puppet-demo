# Class: profiles::nagios::service
#
#   Manage Nagios, fcgiwrap, and php8.3-fpm services
#
class profiles::nagios::service {
  exec { 'Testing Nagios Config':
    command     => '/usr/local/nagios/bin/nagios -v /usr/local/nagios/etc/nagios.cfg',
    refreshonly => true,
  }

  service { 'nagios':
    ensure => running,
  }

  service { 'fcgiwrap':
    ensure  => running,
  }

  service { 'php8.3-fpm':
    ensure => running,
  }
}
