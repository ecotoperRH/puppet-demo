# Class: roles::gitlab
#
#   This role is in charge of installing all necessary GitLab server's components
#
class roles::gitlab inherits roles::base {
  include profiles::gitlab
}
