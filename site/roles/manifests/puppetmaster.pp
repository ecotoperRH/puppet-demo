# Class: roles::puppetmaster
#
# Inherit configurations from roles::base and install configuration for a consul server 
#
class roles::puppetmaster inherits roles::base {
  include profiles::puppetmaster
}
