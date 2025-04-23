# Class: profiles::base::facts
#
# Setup External Custom Facts directories to store custom executable or scripts as facts
#
class profiles::base::facts {
  file {['/etc/facter/', '/etc/facter/facts.d/']:
    ensure => directory,
    purge  => true,
  }
}
