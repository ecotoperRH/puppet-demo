# Class: profiles::release
#
# Set up necessary files for an application and release application when it has new version
#
class profiles::release (
  Hash $applications,
) {
  include nginx
  $applications.each |String $app_name, Hash $configs| {
    profiles::release::app { $app_name:
      * => $configs,
    }
  }
}
