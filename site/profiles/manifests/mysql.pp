# Class: profiles::mysql
#
# Install MySQL for a database server
#
class profiles::mysql {
  # Install MySQL server
  class { 'mysql::server':
    root_password           => 'strongpassword',
    remove_default_accounts => true,
    restart                 => true,
  }

  # Create a 'my-demo-db' database
  mysql::db { 'my-demo-db':
    user     => 'myuser',
    password => 'mypass',
    host     => 'localhost',
    grant    => ['SELECT', 'UPDATE'],
  }
}
