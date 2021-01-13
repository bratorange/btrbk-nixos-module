{ config, lib, pkgs, ... }:

with lib;
with types;
with import ./btrbkHelpers.nix;

let
  conversions = {
    valueIdentityPair = keyName: value:
      if (value != null) then [ (keyName + "  " + value) ] else [];

    customList = value: if (value != null) then value else [];
  };
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
    description = "When should snapshots be created. Always will allways create one, onchange if the subvolume has changed, ondemand if the target is available and no will never create a snapshot.";
    apply = conversions.valueIdentityPair "snapshot_create";
  };
}
