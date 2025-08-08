# Class: profiles::mysql
#
# Install MySQL for a database server
#
class profiles::mysql (
  $is_master = true,
  $override_options = undef,
) {
  # Install MySQL server
  class { 'mysql::server':
    root_password           => 'strongpassword',
    remove_default_accounts => true,
    restart                 => true,
    override_options        => $override_options,
  }

  if $is_master {
    # Create a MySQL admin user to export DB remotely
    mysql_user { 'db_admin@192.168.68.%':
      ensure        => 'present',
      password_hash => mysql::password('PleaseChangeMe'),
    }
    -> mysql_grant { 'db_admin@192.168.68.%/*.*':
      ensure     => 'present',
      options    => ['GRANT'],
      privileges => ['ALL'],
      table      => '*.*',
      user       => 'db_admin@192.168.68.%',
    }

    # Create a MySQL user for replication
    -> mysql_user { 'repl_user@192.168.68.%':
      ensure        => 'present',
      password_hash => mysql::password('PleaseChangeMe'),
    }
    -> mysql_grant { 'repl_user@192.168.68.%/*.*':
      ensure     => 'present',
      privileges => ['REPLICATION SLAVE'],
      table      => '*.*',
      user       => 'repl_user@192.168.68.%',
    }
  }

  # Create a 'my-demo-db' database
  mysql::db { 'my-demo-db':
    user     => 'myuser',
    password => 'mypass',
    host     => 'localhost',
    grant    => ['SELECT', 'UPDATE'],
  }
}
