{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.btrbk;

  list2lines =
    inputList: (builtins.concatStringsSep "\n" inputList) + "\n";

  # TODO use a regex instead?
  lines2list =
    inputLines: builtins.filter isString (builtins.split "\n" inputLines);

  addPrefixes =
    lines: map (line: "  " + line) lines;

  convertEntrys =
    subentry: subentryType: builtins.concatLists (
      map (entry: [(subentryType + " " + entry)] ++ (addPrefixes (lines2list subentry."${entry}")))
      (builtins.attrNames subentry));
  
  convertLists =
    subentry: subentryType: map (entry: subentryType + " " + entry) subentry;

  convertString =
    subentry: subentryType: [ (subentryType + " " + subentry) ];

  renderVolumes =
    list2lines (mapAttrsToList (name: value: 
      # volume head line
      "volume " + name + "\n" 
      # volume extra options
      + (list2lines (addPrefixes (lines2list value.extraOptions))) 
      # volume subvolumes which should be backed up
      + (renderSubsection value "subvolume") 
      # volume backup targets
      + (renderSubsection value "target"))
    cfg.volumes);

  renderSubsection =
    volumeEntry: subsectionType:
      let 
        subsectionEntry = builtins.getAttr (subsectionType + "s") volumeEntry;
        converter =
          # isolate the case, that a subentry was written as a single string
          if isString subsectionEntry then convertString
          else
          # differentiate whether a simple list is used, or if extra options a used for the subentry
          (if (builtins.isAttrs subsectionEntry) then convertEntrys else convertLists);
      in
        list2lines (addPrefixes (converter (builtins.deepSeq subsectionEntry subsectionEntry) subsectionType));

  subsectionDataType = with types; either (either (listOf str) (attrsOf lines)) str;

  extraOptions = mkOption {
    type = with types; nullOr lines;
    default = null;
    example = ''
      snapshot_dir           btrbk_snapshots
    '';
    description = "Extra options which influence how a backup is stored. See digint.ch/btrbk/doc/btrbk.conf.5.html under Options for more information.";
  };

  # map the sections part of the btrbk config into a the module
  volumeSubmodule =
    ({name, config, ... }:
    {
      options = {
        inherit extraOptions;
        subvolumes = mkOption {
            type = subsectionDataType;
            default = [];
            example = [ "/home/user/important_data" "/mount/even_more_important_data"];
            description = "A list of subvolumes which should be backed up.";
        };
        targets = mkOption {
          type = subsectionDataType;
          default = [];
          example = ''[ "/mount/backup_drive" ]'';
          description = "A list of targets where backups of this volume should be stored.";
        };
      };
  });
  in {
    options.programs.btrbk = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the btrbk backup utility for btrfs based file systems.";
      };
      inherit extraOptions;
      volumes = mkOption {
        type = with types; attrsOf (submodule volumeSubmodule);
        default = { };
        description = "The configuration for a specific volume. The key of each entry is a string, reflecting the path of that volume.";
        example = {
         "/mount/btrfs_volumes" =
          {
            subvolumes = [ "btrfs_volume/important_files" ];
            targets = [ "/mount/backup_drive" ];
          };
        };
      };
    };

    ###### implementation
    config = mkIf cfg.enable {
      environment.systemPackages = [ pkgs.btrbk ];
      environment.etc."btrbk/btrbk.conf" = {
        source = pkgs.writeText "btrbk.conf"
          (( optionalString (cfg.extraOptions != null) cfg.extraOptions ) + "\n"
            + renderVolumes);
      };
    };
  }
