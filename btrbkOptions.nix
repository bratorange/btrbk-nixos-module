{ config, lib, pkgs, ... }:

with lib;
with types;
with import ./btrbkHelpers.nix;

let
  conversions = {
    valueIdentityPair = keyName: value:
      if (value != null) then [ (keyName + "  " + value) ] else [];

    intToBoolPair = keyName: value:
      if (value != null) then [ (keyName + "  " + (toString value)) ] else [];

    customList = value: if (value != null) then value else [];

    boolPair = keyName: value:
      if (value != null) then [ (keyName + "  " + (if value then "yes" else "no")) ] else [];
  };

  retentionPolicy = strMatching "(((([0-9]+)|\\*)[hdmy])[ \t\n\r]*)+";
in 
{
  snapshotDir = mkOption {
    type = nullOr str;
    default = null; 
    description = "Directory where snapshots of the filesystem will be stored. Must be given relative to individual volume-directory.";
    apply = conversions.valueIdentityPair "snapshot_dir";
  };

  timestampFormat = mkOption {
    type = nullOr (enum [ "short" "long" "long-iso" ]);
    default = null;
    description = "Timestamp format used as a suffix for new snapshot modules. 'short' only keeps track of the date, 'long' also tracks the time of day and 'long-iso' will also prevent issues with backups made during a time shift.";
     apply = conversions.valueIdentityPair "timestamp_format";
  };

  # change this back again to the lines option
  extraOptions = mkOption {
    type = nullOr (listOf str);
    default = null;
    description = "Extra options which influence how a backup is stored. See digint.ch/btrbk/doc/btrbk.conf.5.html under 'Options' for more information.";
    apply = conversions.customList;
  };

  snapshotName = mkOption {
    type = nullOr str;
    default = null;
    description = "Name of backup'ed subvolume inside the target. Only set if you want the backup have another name than the original subvolume";
    apply = conversions.valueIdentityPair "snapshot_name";
  };

  snapshotCreate = mkOption {
    type = nullOr (enum [ "always" "onchange" "ondemand" "no" ]);
    default = null;
    description = "When should snapshots be created. 'Always' will allways create one, 'onchange' if the subvolume has changed, 'ondemand' if the target is available and 'no' will never create a snapshot.";
    apply = conversions.valueIdentityPair "snapshot_create";
  };

  incremental = mkOption {
    type = nullOr (enum [ "yes" "no" "strict" ]);
    default = null;
    description = "Wether incremental backups will be created. No will only create full backups, yes will only create initial backups non-incremental and strict will only create incremental backups.";
    apply = conversions.valueIdentityPair "incremental";
  };
  
  noauto = mkOption {
     type = nullOr bool;
     default = null;
     apply = conversions.boolPair "noauto";
  };

  # Retention Policy Options
  preserveDayOfWeek = mkOption {
    type = nullOr (enum ["monday" "tuesday" "wednesday" "thursday" "friday" "saturday" "sunday" ] );
    default = null;
    description = "A snapshot done at this day will be considered as weekly. See 'Retention Policy' in (man 5 btrbk.conf) for more information on what that means.";
    apply = conversions.valueIdentityPair "preserve_day_of_week";
  };

  preserveHourOfDay = mkOption {
    type = nullOr (ints.between 0 23);
    default = 5;
    description = "Defines after what time (in full hours since midnight) a snapshot/backup is considered to be a 'daily' backup. Daily, weekly, monthly and yearly backups are preserved on this hour (see RETENTION POLICY in (man 5 btrbk.conf)). If you set this option, make sure to also set timestamp_format to 'long' or 'long-iso' (backups and snapshots having no time information will ignore this option). Defaults to '0'.";
    apply = conversions.intToBoolPair "preserve_hour_of_day";
  };

  snapshotPreserve = mkOption {
    type = nullOr (either (strMatching "no") retentionPolicy);
    default = null;
    description = "Set retention policy for snapshots (see RETENTION POLICY in (man 5 btrbk.conf)). If set to 'no', preserve snapshots according to snapshotPreserveMin only. Defaults to 'no'.";
    example = "5d 4m *y";
    apply = conversions.valueIdentityPair "snapshot_preserve";
  };

  # SSH Options
  sshIdentity = mkOption {
    type = nullOr path;
    default = null;
    description = "Absolute path to a ssh private key to authentificate at the target machine.";
    apply = conversions.valueIdentityPair "ssh_identity";
  };

  sshUser = mkOption {
    type = nullOr str;
    default = null;
    description = "User on the target machine. Defaults to 'root'.";
    apply = conversions.valueIdentityPair "ssh_user";
  };

  sshCompression = mkOption {
    type = nullOr bool;
    default = null;
    description = "Enables or disables the compression of ssh connections. Defaults to false. Note that if streamCompress is enabled, ssh compression will always be disabled for send/receive operations.";
    apply = conversions.boolPair "ssh_compression";
  };

  sshCipherSpec = mkOption {
    type = nullOr str;
    default = null;
    description = "Selects the cipher specification for encrypting the session (comma-separated list of ciphers in order of preference). See the '-c cipher_spec' option in ssh(1) for more information. Defaults to 'default' (the ciphers specified in ssh_config)";
    apply = conversions.valueIdentityPair "ssh_cipher_spec";
  };
}
