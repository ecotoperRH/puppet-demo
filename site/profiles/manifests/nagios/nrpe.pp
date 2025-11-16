# Class: profiles::nagios::nrpe
#  
#   This class install NRPE package and nagios-plugins
#
class profiles::nagios::nrpe {
  # We need 'nagios-nrpe-server' package on both Nagios server and all remote hosts
  # Because I installed nagios-plugins' from source code, so it becomes optional for 'nagios-server'.
  # But we still need it on all remote hosts. We can set like this to manipulate options:
  $required_package = $trusted['hostname'] ? {
    'nagios-server' => ['nagios-nrpe-server', 'nagios-nrpe-plugin'], # packages for Nagios Server
    default         => ['nagios-nrpe-server', 'nagios-plugins'],     # packages for the rest
  }

  # NOTE: The $required_package variable above is for Debian/Ubuntu. 
  # If you come from any other distro, please check the corresponding packages
  class { 'nrpe':
    allowed_hosts   => ['127.0.0.1', 'nagios-server.srv.local'],
    package_name    => $required_package,
    dont_blame_nrpe => true, # Allow Nagios server to pass arguments to the remote host.
    purge           => true, # Remove NRPE commands are configured by default when install package
  }
}
