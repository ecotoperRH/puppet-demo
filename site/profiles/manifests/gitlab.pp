# Class: profiles::gitlab
#
#  This profile use puppet-gitlab module to install and set up a GitLab server.
#  We can also include other classes (for other configurations) here that the GitLab server need
#
class profiles::gitlab {
  include gitlab
}
