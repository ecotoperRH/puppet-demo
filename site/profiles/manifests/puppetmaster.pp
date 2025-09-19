# Class: profiles::puppetmaster
#
#   Set up necessary tools for puppet-master (Puppet Server) server
#
#   @param challenge_password is the secret password where Puppet Server uses to validate whether requests from agent nodes is valid
#
class profiles::puppetmaster (
  String $challenge_password,
) {
  # Set up "check_csr.sh" from a template to /usr/local/bin
  file { '/usr/local/bin/check_csr.sh':
    ensure  => 'file',
    content => template('profiles/puppetmaster/check_csr.sh.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0751',
  }
}
