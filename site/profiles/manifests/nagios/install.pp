# Class: profiles::nagios::install
#
#  Download and Install Nagios from source code
#
class profiles::nagios::install {
  $nagios_owner          = $profiles::nagios::owner
  $nagios_group          = $profiles::nagios::group
  $full_pkg_name         = $profiles::nagios::full_pkg_name
  $archive_name          = $profiles::nagios::archive_name
  $nagios_package_source = $profiles::nagios::nagios_package_source
  $install_path          = $profiles::nagios::install_path
  $full_extracted_path   = $profiles::nagios::full_extracted_path

  file { $install_path:
    ensure => directory,
  }

  # Make sure apache2 packages are not installed.
  $unavailable_packages = [
    'apache2-bin',
    'apache2',
    'libapache2-mod-php8.3',
  ]
  package { $unavailable_packages:
    ensure   => absent,
    provider => apt,
  }

  ::apt::pin { 'Forbidden packages':
    explanation => 'Force Apt ignore this package even it is in depends',
    packages    => $unavailable_packages,
    release     => '*',
    priority    => -1,
  }

  $required_packages = [
    'autoconf',
    'gcc',
    'libc6',
    'make',
    'wget',
    'libgd-dev',
    'ufw',
    'openssl',
    'libssl-dev',
    'apache2-utils', # Contain htpasswd command to create hash password for basic Nginx Auth

    # If we plan to set up a PHP class to install on any web server in the future
    # We can consider move these php-* packages to a separate profile.
    # That's when we can just call that profile, e.g. profiles::php::install
    # without declaring these packages here. In this example, I'll set up
    # them here for simplicity.
    'php8.3',
    'php8.3-fpm',
    'php8.3-common',
    'php8.3-cli',
    'php8.3-mbstring',
    'php8.3-bcmath',
    'php8.3-mysql',
    'php8.3-zip',
    'php8.3-gd',
    'php8.3-curl',
    'php8.3-xml',

    'fcgiwrap',
  ]

  # Installs all required packages
  package { $required_packages:
    ensure => 'present',
  }

  # Download the Nagios Core source code and extract it to a desired path.
  archive { $archive_name:
    path         => "/tmp/${archive_name}",
    source       => $nagios_package_source,
    extract      => true,
    extract_path => $install_path,
    creates      => $full_extracted_path,
    cleanup      => true,
    require      => File[$install_path],
  }

  # Create user and group: 'www-data'
  group { 'www-data':
    ensure => present,
  }

  user { 'www-data':
    ensure  => present,
    gid     => 'www-data',
    require => Group['www-data'],
  }

  # Create user and group: 'nagios', also assign 'nagios' user to 'www-data' group.
  group { $nagios_owner:
    ensure => present,
  }

  user { $nagios_group:
    ensure  => present,
    gid     => $nagios_group,
    groups  => 'www-data',
    require => [Group[$nagios_group], Group['www-data']],
  }

  ## This section is to install Nagios Core

  # Execute the Nagios Core configure script
  # The 'creates' attribute is to tell Puppet should run 'configure' once
  # if the specified file does not exist. Indicates that we haven't set up Nagios.
  # If this 'exec' attribute doesn't run, all the subsequent exec skip 
  # running as well.
  exec { 'Creating Nagios sample config files':
    command => "${full_extracted_path}/configure --with-httpd-conf=/etc/nginx/sites-enabled",
    cwd     => $full_extracted_path,
    creates => '/usr/lib/systemd/system/nagios.service',
    require => Archive[$archive_name],
  }

  # Compile the main program and CGI
  ~> exec { 'Compiling the main program':
    command => 'make all',
    cwd     => $full_extracted_path,
    creates => '/usr/lib/systemd/system/nagios.service',
  }

  # Installs Nagios Core, it includes the binary files, CGIs, and HTML files.
  ~> exec { 'Installing Nagios Core':
    command => 'make install',
    cwd     => $full_extracted_path,
    creates => '/usr/lib/systemd/system/nagios.service',
  }

  # Set up the service or daemon files and also configures them to start on boot.
  ~> exec { 'Creating systemd config files for nagios service':
    command => 'make install-daemoninit',
    cwd     => $full_extracted_path,
    creates => '/usr/lib/systemd/system/nagios.service',
  }

  # Installs and configures the external command file
  # 'refreshonly' attribute makes this exec runs only if the previous exec runs
  ~> exec { 'Installing external commands.cfg file':
    command     => 'make install-commandmode',
    cwd         => $full_extracted_path,
    refreshonly => true,
  }

  # Installs Nagios sample configuration files
  ~> exec { 'Installing Nagios sample configuration files':
    command     => 'make install-config',
    cwd         => $full_extracted_path,
    refreshonly => true,
  }
}
