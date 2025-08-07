# Class: roles::consul
#
# Inherit configurations from roles::base and install configuration for a consul server 
#
class roles::consul inherits roles::base {
  include profiles::consul
}
