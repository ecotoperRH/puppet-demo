# Class: roles::database
#
# Inherit configurations from roles::base and install configuration for a database server 
#
class roles::database inherits roles::base {
  include profiles::mysql
}
