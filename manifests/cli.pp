# @summary Manage Sensu CLI
#
# Class to manage the Sensu CLI.
#
# @example
#   class { 'sensu::cli':
#     password => 'secret',
#   }
#
# @param version
#   Version of sensu-go-cli to install.  Defaults to `installed` to support
#   Windows MSI packaging and to avoid surprising upgrades.
# @param package_name
#   Name of Sensu CLI package.
# @param install_source
#   Source of Sensu Go CLI download for installing on Windows.
#   Paths with http:// or https:// will be downloaded
#   Paths with puppet:// or file:// paths will also be installed.
# @param install_path
#   Where to install sensuctl for Windows. Default to `C:\Program Files\Sensu`.
# @param configure
#   Determines if sensuctl should be configured
# @param sensuctl_chunk_size
#   Chunk size to use when listing sensuctl resources
# @param config_format
#   Default format for sensuctl
# @param config_namespace
#   Default namespace for sensuctl
#
class sensu::cli (
  Optional[String] $version = undef,
  String $package_name = 'sensu-go-cli',
  Optional[Variant[Stdlib::HTTPSUrl, Stdlib::HTTPUrl, Pattern[/^(file|puppet):/]]] $install_source = undef,
  Optional[Stdlib::Absolutepath] $install_path = undef,
  Boolean $configure = true,
  Optional[Integer] $sensuctl_chunk_size = undef,
  Optional[Enum['tabular','json','wrapped-json','yaml']] $config_format = undef,
  Optional[String] $config_namespace = undef,
) {

  include sensu
  include sensu::common

  $ssl_dir = $sensu::ssl_dir
  $use_ssl = $sensu::use_ssl
  $_version = pick($version, $sensu::version)
  $api_url = $sensu::api_url
  $password = $sensu::password

  if $use_ssl {
    $trusted_ca_file = $sensu::trusted_ca_file_path
    if $configure {
      Class['sensu::ssl'] -> Sensuctl_configure['puppet']
    }
  } else {
    $trusted_ca_file = 'absent'
  }

  if $facts['os']['family'] == 'windows' {
    if ! $install_source {
      fail('sensu::cli: install_source is required for Windows')
    }
    $sensuctl_path = "${install_path}\\sensuctl.exe"
    file { $install_path:
      ensure => 'directory',
    }
    archive { 'sensu-go-cli.zip':
      path         => "${install_path}\\sensu-go-cli.zip",
      source       => $install_source,
      extract      => true,
      extract_path => $install_path,
      creates      => "${install_path}\\sensuctl.exe",
      cleanup      => false,
      require      => File[$install_path],
    }
    windows_env { 'sensuctl-path':
      ensure    => 'present',
      variable  => 'PATH',
      value     => $install_path,
      mergemode => 'append',
      require   => Archive['sensu-go-cli.zip'],
    }
  } else {
    $sensuctl_path = undef
    package { 'sensu-go-cli':
      ensure  => $_version,
      name    => $package_name,
      require => $sensu::package_require,
    }
  }

  if $configure {
    sensuctl_config { 'sensu':
      chunk_size => $sensuctl_chunk_size,
      path       => $sensuctl_path,
    }

    sensuctl_configure { 'puppet':
      url              => $api_url,
      username         => 'admin',
      password         => $password,
      old_password     => $sensu::old_password,
      trusted_ca_file  => $trusted_ca_file,
      config_format    => $config_format,
      config_namespace => $config_namespace,
    }
  }
}
