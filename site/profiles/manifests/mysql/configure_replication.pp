# Class: profiles::mysql::configure_replication
#
# Configure MySQL replication on slave
#
class profiles::mysql::configure_replication {
  $configure_repl_script = '/usr/local/bin/configure_replication.sh'
  file { $configure_repl_script:
    ensure => 'file',
    source => 'puppet:///modules/profiles/mysql/configure_replication.sh',
    owner  => 'root',
    group  => 'root',
    mode   => '0700',
    notify => Exec['configure_replication'],
  }

  # $facts['path'] sets to "/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin:/opt/puppetlabs/bin"
  exec { 'configure_replication':
    command     => "${configure_repl_script} >> /var/log/configure-mysql-repl.log 2>&1",
    environment => ['HOME=/root', 'USER=root'],
    path        => $facts['path'],
    user        => 'root',
    unless      => ['test -f /tmp/.replication.done'],
  }
}
