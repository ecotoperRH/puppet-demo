# Class: profiles::base::packages
#
# Install the necessary packages for the host.
# 
class profiles::base::packages {
  $packages = [
    'socat',
    'net-tools',
    'curl',
  ]

  package { $packages:
    ensure => installed,
  }
}
