# Class: profiles::nagios
#
#  Install and setup Nagios-related configurations for a Nagios server
#  We can also include other classes (for other configurations) here that the GitLab server need
#
class profiles::nagios (
  String $package_name        = 'nagios',
  String $package_ensure      = '4.5.9',
  String $repository_url      = 'https://github.com/NagiosEnterprises/nagioscore/releases/download',
  String $full_pkg_name       = "${package_name}-${package_ensure}",
  String $archive_name        = "${full_pkg_name}.tar.gz",
  String $nagios_package_source = "${repository_url}/${full_pkg_name}/${archive_name}",
  String $install_path        = '/opt/nagios',
  String $config_path         = '/usr/local/nagios/etc',
  String $full_extracted_path = "${install_path}/${full_pkg_name}",
  String $admin_user,
  String $admin_password,
  String $owner               = 'nagios',
  String $group               = 'nagios',
) {
  contain profiles::nagios::install
  contain profiles::nagios::plugin
  contain profiles::nagios::configure
  contain profiles::nagios::service
  include nginx

  # Nginx server block configuration for nagios-server.srv.local site.
  nginx::resource::server { 'nagios-server.srv.local':
    listen_port          => 80,
    www_root             => '/usr/local/nagios/share',
    access_log           => '/var/log/nginx/nagios.access.log',
    error_log            => '/var/log/nginx/nagios.error.log',
    auth_basic           => 'Nagios Auth',
    auth_basic_user_file => '/usr/local/nagios/etc/htpasswd.users',
    use_default_location => false,
    raw_prepend          => ['rewrite ^/nagios/(.*) /$1;'],
    locations            => {
      '/'                => {
        try_files => ['$uri', '$uri/', 'index.php'],
      },
      '~ ^/?(.*\\.php)$' => {
        try_files => ['$uri = 404'],
        fastcgi   => 'unix:/run/php/php8.3-fpm.sock',
      },
      '~ \\.cgi$'        => {
        fastcgi_param => {
          'AUTH_USER'   => '$remote_user',
          'REMOTE_USER' => '$remote_user',
        },
        fastcgi       => 'unix:/run/fcgiwrap.socket',
      },
    },
    # locations_defaults sets configurations that all "locations" defined above should have 
    locations_defaults   => {
      www_root    => undef,
      index_files => [],
    },
  }

  # Specify execution order of classes
  Class['profiles::nagios::install']
  -> Class['profiles::nagios::plugin']
  -> Class['profiles::nagios::configure']
  -> Class['profiles::nagios::service']
  -> Class['nginx']
}
