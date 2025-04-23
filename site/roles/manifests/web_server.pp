# Class: roles::web_server
#
# Inherit configurations from roles::base and install configurations for a web server
#
class roles::web_server inherits roles::base {
  include profiles::golang
  include profiles::nginx
}
