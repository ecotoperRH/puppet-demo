# Class: profiles::puppetmaster
#
#   Set up necessary tools for puppet-master (Puppet Server) server
#
#   @param challenge_password is the secret password where Puppet Server uses to validate whether requests from agent nodes is valid
#   @param puppetdb_database_password is the secret password for 'puppetdb' user created on PostgreSQL 14
#
class profiles::puppetmaster (
  String $challenge_password,
  String $puppetdb_database_password,
) {
  # Set up "check_csr.sh" from a template to /usr/local/bin
  file { '/usr/local/bin/check_csr.sh':
    ensure  => 'file',
    content => template('profiles/puppetmaster/check_csr.sh.erb'),
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
  }

  # I'm running Puppet Server version 8.8.1-1+ubuntu24.04
  # According to https://help.puppet.com/core/current/Content/PuppetCore/platform_lifecycle.htm
  # The compatible PuppetDB version should be 8.9.0
  class { 'puppetdb::globals':
    version => '8.9.1-1+ubuntu24.04',
  }

  # Configure puppetdb and its underlying database
  # NOTE: Because I'm installing Puppet Server/agent packages under Openvox Repo
  # They are openvox-server/openvox-agent
  # Therefore, the package name of PuppetDB should become 'openvoxdb' instead of 'puppetdb'. It's just a change of package name only
  # Other commands in regard to PuppetDB remain the same under openvoxdb package
  class { 'puppetdb':
    puppetdb_package  => 'openvoxdb',
    terminus_package  => 'openvoxdb-termini',
    database_password => $puppetdb_database_password,   # Change the default password 'puppetdb' to my own
    java_args         => {
      '-Xmx' => '512m',
      '-Xms' => '256m',
    },
  }

  # Configure the Puppet Server to use puppetdb
  class { 'puppetdb::master::config': }
}
