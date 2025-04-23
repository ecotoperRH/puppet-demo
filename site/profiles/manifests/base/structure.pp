# Class: profiles::base::structure
#
# Set up system-wide file structure
#
class profiles::base::structure {
  # All created directories below will have owner and group are 'root'
  File {
    owner => 'root',
    group => 'root',
  }

  file {['/opt/', '/data', '/data/app']:
    ensure => directory,
  }
}
