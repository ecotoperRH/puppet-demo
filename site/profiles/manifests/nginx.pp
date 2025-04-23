# Class: profiles::nginx
#
# Set up web server that includes nginx-related configuration
#
class profiles::nginx {
  include nginx

  $web_demo_name = 'web-demo'

  # Set up the "web-demo" binary file to path /data/app/
  file { "/data/app/${web_demo_name}":
    ensure => file,
    source => "puppet:///modules/profiles/nginx/${web_demo_name}/${web_demo_name}",
    mode   => '0755',
  }

  # Configure "web-demo" systemd service to run "/data/app/web-demo"
  file { "/etc/systemd/system/${web_demo_name}.service":
    ensure => file,
    mode   => '0644',
    owner  => 'root',
    group  => 'root',
    source => "puppet:///modules/profiles/nginx/${web_demo_name}.service",
    notify => Exec["${web_demo_name}-systemd-reload"],
  }

  # Reload daemon only after configuring systemd
  exec { "${web_demo_name}-systemd-reload":
    command     => 'systemctl daemon-reload',
    path        => ['/usr/bin', '/bin', '/usr/sbin'],
    refreshonly => true,
  }

  # Start "web-demo" service to listen requests sent from Nginx
  service { $web_demo_name:
    ensure  => running,
    require => [File["/data/app/${web_demo_name}"], File["/etc/systemd/system/${web_demo_name}.service"]],
  }

  # Configure Nginx host to forward requests to the "web-demo" app
  nginx::resource::server { 'my-webserver.srv.local':
    listen_port => 80,
    proxy       => 'http://localhost:3000',
  }
}
