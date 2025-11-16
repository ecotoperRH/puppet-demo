# Class: profiles::consul::consul_template
#
#
class profiles::consul::consul_template (
  String $package_name         = 'consul-template',
  String $package_ensure       = '0.41.3',
  String $repository_url       = "https://releases.hashicorp.com/${package_name}/${package_ensure}",
  String $full_pkg_name        = "${package_name}_${package_ensure}",
  # Should change the arch (_linux_amd64) to your corresponding arch. E.g. consul-template_linux_arm64.zip
  String $archive_name         = "${full_pkg_name}_linux_amd64.zip",
  String $download_url         = "${repository_url}/${archive_name}",
  String $install_path         = '/opt/consul-template',
  String $config_path          = '/etc/consul-template',
  String $usr_local_bin_path   = '/usr/local/bin',
  String $full_extracted_path  = "${install_path}/archives",
  String $consul_owner         = 'consul',
  String $consul_group         = 'consul',
) {
  # Ensure all file created with these owner/group/permission options 
  File {
    owner => $consul_owner,
    group => $consul_group,
    mode  => '0644',
  }

  # Create necessary config paths
  file { [$install_path, $config_path, $full_extracted_path]:
    ensure => directory,
  }
  # Download the consul-template binary zip file and extract it to a desired path,
  # which is $full_extracted_path in this case
  archive { $archive_name:
    path         => "/tmp/${archive_name}",
    source       => $download_url,
    extract      => true,
    extract_path => $full_extracted_path,
    creates      => "${full_extracted_path}/${package_name}",
    cleanup      => true,
    require      => [File[$install_path], File[$full_extracted_path]],
  }

  # Create a symlink to /usr/local/bin/consul-template
  file { "${usr_local_bin_path}/${package_name}":
    ensure  => link,
    target  => "${full_extracted_path}/${package_name}",
    require => Archive[$archive_name],
  }

  # Set up a config file for consul-template. This is to tell consul-template where to query nodes' details.
  file { "${config_path}/config.hcl":
    ensure => 'file',
    source => "puppet:///modules/profiles/consul/${package_name}/etc/config.hcl",
  }

  # Set sudo permission to consul-template binary so that it can reload service as root
  file { '/etc/sudoers.d/sudo-consul':
    ensure  => 'file',
    content => "consul ALL = (root) NOPASSWD: ${usr_local_bin_path}/${package_name} *",
    owner   => 'root',
    group   => 'root',
  }

  # Create a systemd service config for consul-template.service.
  # This code block generates /etc/systemd/system/consul-template.service file with specified parameters below
  systemd::manage_unit { "${package_name}.service":
    unit_entry    => {
      'Description' => 'Consul-Template Daemon Service',
      'Wants'       => ['basic.target'],
      'After'       => ['basic.target', 'network.target'],
    },
    service_entry => {
      'User'              => $consul_owner,
      'Group'             => $consul_group,
      'ExecStart'         => "sudo ${usr_local_bin_path}/${package_name} -config ${config_path}",
      'SuccessExitStatus' => '12',
      'ExecReload'        => '/bin/kill -SIGHUP $MAINPID',
      'ExecStop'          => '/bin/kill -SIGINT $MAINPID',
      'KillMode'          => 'process',
      'Restart'           => 'always',
      'RestartSec'        => '42s',
      'LimitNOFILE'       => '4096',
    },
    install_entry => {
      'WantedBy' => 'multi-user.target',
    },
    enable        => true,
    active        => true, # 'true' means start this service after created
  }
}
