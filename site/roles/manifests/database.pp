# Class: roles::database
#
# Inherit configurations from roles::base and install configuration for a database server 
#
class roles::database inherits roles::base {
  include profiles::mysql
  $is_master = lookup('profiles::mysql::is_master', { 'default_value' => true })
  if !$is_master {
    include profiles::mysql::configure_replication

    # Instruct Puppet to know that it should run class 'profiles::mysql' prior to 'profiles::mysql::configure_replication'
    Class['profiles::mysql'] -> Class['profiles::mysql::configure_replication']
  }
}
