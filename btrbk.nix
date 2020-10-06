{ config, lib, pkgs, ... }:

with lib;
with debug;

let
  cfg = config.programs.btrbk;

  list2lines =
    inputList: (builtins.concatStringsSep "\n" inputList) + "\n";

  lines2list =
    inputLines: builtins.filter isString (builtins.split "\n" inputLines);

  addPrefixes =
    lines: map (line: "  " + line) lines;

  setToNameValuePairs = 
    entrys: map (name:
      {
        name = name;
        value = entrys."${name}";
      })
    (builtins.attrNames entrys);

  convertEntrys =
    subentry: subentryType: builtins.concatLists (
      map (entry: [(subentryType + " " + entry)] ++ (addPrefixes (lines2list subentry."${entry}")))
      (builtins.attrNames subentry));
  
  convertLists =
    subentry: subentryType: map (entry: subentryType + " " + entry) subentry;

  checkForSubAttrs =
    listOrAttrs: builtins.isAttrs listOrAttrs;

  renderVolumes =
    list2lines (map (pair: 
      # volume head line
      "volume " + pair.name + "\n" 
      # volume extra options
      + (list2lines (addPrefixes (lines2list pair.value.extraOptions))) 
      # volume subvolumes which should be backed up
      + (renderSubsection pair.value "subvolume") 
      # volume backup targets
      + (renderSubsection pair.value "target"))
    (setToNameValuePairs cfg.volumes));

  renderSubsection =
    volumeEntry: subsectionType:
      let 
        subsectionEntry = builtins.getAttr (subsectionType + "s") volumeEntry;
        converter = if (checkForSubAttrs subsectionEntry) then convertEntrys else convertLists;
      in
        list2lines (addPrefixes (converter (builtins.deepSeq subsectionEntry subsectionEntry) subsectionType));

  extraOptions = mkOption {
    type = with types; nullOr lines;
    default = null;
    example = ''
      snapshot_dir           btrbk_snapshots
    '';
    description = ''
      Extra options which influence how a backup is stored. See digint.ch/btrbk/doc/btrbk.conf.5.html under Options for more information.
    '';
  };

  # map the sections part of the btrbk config into a the module
  volume_submodule =
    ({name, config, ... }:
    {
      options = {
        inherit extraOptions;
        subvolumes = mkOption {
            type = with types; either (listOf str) (attrsOf lines);
            default = [];
            example = ''[ "/home/user/important_data" ]'';
            description = ''
              A list of subvolumes which should be backed up.
            '';
        };
        targets = mkOption {
          # TODO single argument syntactical sugar
          type = with types; either (listOf str) (attrsOf lines);
          default = [];
          example = ''[ "/mount/backup_drive" ]'';
          description = ''
            A list of targets where backups of this volume should be stored.
          '';
        };
      };
  });
  in {
    options.programs.btrbk = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Enable the btrbk backup utility for btrfs based file systems.
        '';
      };
      inherit extraOptions;
      volumes = mkOption {
        type = with types; attrsOf (submodule volume_submodule);
        default = { };
        # TODO write description and example
      };
    };

    ###### implementation
    config = mkIf cfg.enable {
      environment.systemPackages = [ pkgs.btrbk ];
      environment.etc."btrbk/btrbk.conf" = {
        source = pkgs.writeText "btrbk.conf"
          (( optionalString (cfg.extraOptions != null) cfg.extraOptions )
            + renderVolumes);
      };
    };
  }
