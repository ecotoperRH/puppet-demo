# Class: profiles::nagios::plugin
#
#  This class install 'nagios-plugin' from source code for Nagios.
#  You can also install 'nagios-plugin' package provided distro.
#  I installed Nagios from source code, so just want to install this plugin
#  from source code for consistency
#
class profiles::nagios::plugin (
  String $package_name         = 'nagios-plugins',
  String $package_ensure       = '2.4.12',
  String $repository_url       = 'https://github.com/nagios-plugins/nagios-plugins/releases/download',
  String $full_pkg_name        = "${package_name}-${package_ensure}",
  String $archive_name         = "${full_pkg_name}.tar.gz",
  String $nagios_plugin_source = "${repository_url}/release-${package_ensure}/${archive_name}",
  String $install_path         = $profiles::nagios::install_path,
  String $full_extracted_path  = "${install_path}/${full_pkg_name}",
  String $nagios_owner         = $profiles::nagios::owner,
  String $nagios_group         = $profiles::nagios::group,
) {
  # Download the Nagios Plugin source code and extract it to a desired path.
  archive { $archive_name:
    path         => "/tmp/${archive_name}",
    source       => $nagios_plugin_source,
    extract      => true,
    extract_path => $install_path,
    creates      => $full_extracted_path,
    cleanup      => true,
  }

  exec { 'Configuring nagios-plugin source code':
    command     => "${full_extracted_path}/configure --with-nagios-user=${nagios_owner} --with-nagios-group=${nagios_group}",
    cwd         => $full_extracted_path,
    subscribe   => Archive[$archive_name],
    refreshonly => true,
  }

  # Compile and install nagios-plugins
  ~> exec { 'Compiling and Installing nagios-plugins':
    command     => 'make && make install',
    cwd         => $full_extracted_path,
    refreshonly => true,
    notify      => Exec['Testing Nagios Config'],
  }
}
