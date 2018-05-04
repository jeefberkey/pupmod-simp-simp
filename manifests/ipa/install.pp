# Run ipa-client-install on puppet clients
#
# @param ensure
#   'present' to install, 'absent' to uninstall
#
# @param enroll
#   Be smart about when to run `ipa-client-install`
#
# @param ip_address
#   IP address of host being connected
#
# @param hostname
#   Hostname of the host being connected
#
# @param password
#   Admin or host-based one-time-password generated by `ipa host-add` or the GUI
#
# @param server
#   IPA server to connect to
#
# @param domain
#   IPA Domain
#
# @param realm
#   IPA Realm
#
# @param no_ac
#   Run without authconfig
#
# @param force
#   Force joining
#
# @param install_options
#   Hash of other options for the `ipa-client-install` command.
#
#   @see `ipa-client-install --help`
#
# @param package_ensure
#   Ensure attribute of the package resource managing the `ipa-client` package
#
class simp::ipa::install (
  Enum['present','absent']    $ensure,
  Enum['auto','force','no']   $enroll     = 'auto',
  Optional[Simplib::IP]       $ip_address = undef,
  Optional[String]            $hostname   = undef,
  Optional[String]            $password   = undef,
  Optional[Simplib::Hostname] $server     = undef,
  Optional[Simplib::Hostname] $domain     = undef,
  Optional[String]            $realm      = undef,
  Boolean                     $no_ac      = true,
  Boolean                     $force      = false,
  Hash                        $install_options = {},
  String $package_ensure = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' }),
){

  # Determine whether or not to run the join command
  case $enroll {
    'auto': {
      if $facts['ipa'] {
        $_run_install = ($facts['ipa']['domain'] != $domain) or ($facts['ipa']['realm'] != $realm)
      }
      else {
        $_run_install = true
      }
    }
    'force': {
      $_run_install = true
    }
    'no': {
      $_run_install = false
    }
    default: {
      fail('simp::ipa::install: $enroll must be either `auto`, `force`, or `no`.')
    }
  }


  # assemble important options into hash, then remove ones that are undef
  # all of these options require a value
  $opts = {
    'password'   => $password,
    'server'     => $server,
    'ip-address' => $ip_address,
    'domain'     => $domain,
    'realm'      => $realm,
    'hostname'   => $hostname,
  }.filter |$opt| { $opt[1] !~ Undef }

  $_no_ac = $no_ac ? { true => { 'noac'  => undef }, default => {} }
  $_force = $force ? { true => { 'force' => undef }, default => {} }

  # convert the hash into a string
  $expanded_options = simplib::hash_to_opts($install_options + $_no_ac + $_force + $opts)


  if $ensure == 'present' {
    if $_run_install {
      exec { 'ipa-client-install install':
        command   => "/sbin/ipa-client-install --unattended ${expanded_options}",
        logoutput => true
      }
    }
  }
  else {
    exec { 'ipa-client-install uninstall':
      command   => '/sbin/ipa-client-install --uninstall --unattended',
      logoutput => true,
      notify    => Reboot_notify['ipa-client-unstall uninstall']
    }
    # you might not have to do this
    reboot_notify { 'ipa-client-unstall uninstall':
      reason => 'simp::ipa::install: removing host from IPA domain'
    }
  }

  package { 'ipa-client':
    ensure => $package_ensure,
  }
}
