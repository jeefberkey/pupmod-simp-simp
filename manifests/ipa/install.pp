# @summary Run ipa-client-install on puppet clients
#
# @note Not all parameters here are required. If the DNS is properly configured
#   on the host, nothing needs to be set besides $password. Be sure to read the
#   man page in ipa-client-install or the help for guidance
#
# @note This class supports adding a host to a domain and removing it, but not
#   changing it
#
# @param ensure
#   'present' to add host to an IPA domain, 'absent' to remove
#
# @param enroll
#   Try to determine when to run the ``ipa-client-install`` command. There are
#   a few different joining options:
#
#     * ``auto`` - If the ``ipa`` fact is not present, join the domain
#     * ``always`` - Run the command at every Puppet run
#     * ``never`` - Never runthe command
#
# @param ip_address
#   IP address of host being connected
#
# @param hostname
#   Hostname of the host being connected
#
# @param password
#   The password used for joining. The password can be of one of two types:
#     * A user password. If this is a user password, $principal needs to be
#       set as well
#     * A one time password. A host-based one-time-password generated by
#       ``ipa host-add`` or the GUI
#
# @param principal
#   The user principal that $password relates to
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
#   Run without authconfig, default on systems with ``simp/pam``
#
# @param force
#   Force joining, ignoring errors
#
# @param install_options
#   Hash of other options for the ``ipa-client-install`` command
#
#   @see ``ipa-client-install --help``
#
# @param package_ensure
#   Ensure attribute of the package resource managing the ``ipa-client`` package
#
class simp::ipa::install (
  Enum['present','absent']      $ensure,
  Enum['auto','always','never'] $enroll    = 'auto',
  Optional[Simplib::IP]         $ip_address = undef,
  Optional[Simplib::Hostname]   $hostname   = undef,
  Optional[String]              $password   = undef,
  Optional[String]              $principal  = undef,
  Optional[Simplib::Hostname]   $server     = undef,
  Optional[Simplib::Hostname]   $domain     = undef,
  Optional[String]              $realm      = undef,
  Boolean                       $no_ac      = true,
  Boolean                       $force      = false,
  Hash                          $install_options = {},
  String $ipa_client_ensure  = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' }),
  String $admin_tools_ensure = simplib::lookup('simp_options::package_ensure', { 'default_value' => 'installed' }),
) {
  contain 'simp::ipa::packages'

  if $domain and $enroll == 'auto' {
    if $facts['ipa'] {
      if $facts['ipa']['domain'] != $domain {
        fail("simp::ipa::install: This host is already a member of domain ${facts['ipa']['domain']}, cannot join domain ${domain}")
      }
    }
  }

  # Determine whether or not to run the join command
  case $enroll {
    'always': { $_run_install = true  }
    'never':  { $_run_install = false }
    'auto':   { $_run_install = $facts['ipa'] ? { Undef => true, default => false } }
    default:  { fail('simp::ipa::install: $enroll must be either `auto`, `always`, or `never`.') }
  }


  # assemble important options into hash, then remove ones that are undef
  # all of these options require a value
  $opts = {
    'password'   => $password,
    'principal'  => $principal,
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
        command   => "ipa-client-install --unattended ${expanded_options}",
        logoutput => true,
        path      => ['/sbin','/usr/sbin'],
        require   => Class['simp::ipa::packages']
      }
    }
  }
  else {
    exec { 'ipa-client-install uninstall':
      command   => 'ipa-client-install --unattended --uninstall',
      logoutput => true,
      path      => ['/sbin','/usr/sbin'],
      require   => Class['simp::ipa::packages'],
      notify    => Reboot_notify['ipa-client-unstall uninstall']
    }
    # you might not have to do this
    reboot_notify { 'ipa-client-unstall uninstall':
      reason => 'simp::ipa::install: removed host from IPA domain'
    }
  }
}
