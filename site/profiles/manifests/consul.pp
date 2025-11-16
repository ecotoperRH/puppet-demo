# Class: profiles::consul
#
# Install and setup Consul-related configurations for servers
# 
# @param configs Aggregates Consul configuration data defined in Hiera corresponding to the server/agent mode
#
class profiles::consul (
  Hash $configs = undef,
) {
  # Configure Consul cluster for server and agent nodes
  class { 'consul':
    config_hash => $configs,
  }

  # Install and Configure consul-template
}
