{ config, lib, pkgs, ... }:

with lib;
with import ./btrbkHelpers.nix;

let
  conversions = {
    valueIdentityPair = keyName: value:
      [ (optionalString (value != null) (keyname + "  " + value)) ];

    customLines = value: lines2list value;
  };
in 
{
  snapshotDir = mkOption {
    type = types.nullOr types.str;
    default = null; 
    description = "Directory where snapshots of the filesystem will be stored. Must be given relative to individual volume-directory.";
    apply = conversions.valueIdentityPair "snapshot_dir";
  };

  timestampFormat = mkOption {
    type = types.nullOr (types.enum [ "short" "long" "long-iso" ]);
    default = null;
    description = "Timestamp format used as a suffix for new snapshot modules. 'short' only keeps track of the date, 'long' also tracks the time of day and 'long-iso' will also prevent issues with backups made during a time shift.";
     apply = conversions.valueIdentityPair "timestamp_format";
  };

  extraOptions = mkOption {
    type = with types; nullOr lines;
    default = null;
    description = "Extra options which influence how a backup is stored. See digint.ch/btrbk/doc/btrbk.conf.5.html under 'Options' for more information.";
    apply = conversions.customLines;
  };
  

  # renderOptions :: attrs -> lines
  renderOptions = options:
    list2lines(
      mapAttrsToList(
        # Defining the mapping function
        name: value:
          optionalString (value != null) ((builtins.getAttr name optionMappings) + "  " + value)
      )
      (filterAttrs (name: value: builtins.hasAttr name optionMappings) options))
      + optionalString (options.extraOptions != null) options.extraOptions;
}
