{ config, lib, pkgs, ... }:

with lib;
with debug;

let
  list2lines =
    inputList: builtins.concatStringsSep "\n" inputList;

  lines2list =
    inputLines: builtins.split "\n" inputLines;

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
    subentry: builtins.concatLists (map (subvolume: [subvolume] ++ (addPrefixes (lines2list subentry."${subvolume}"))) (builtins.attrNames subentry));
  
  convertLists =
    subentry: subentry;

  checkForSubAttrs =
    elem: entry:
    let
      names = builtins.attrNames elem;
    in
    # TODO add abort statement if nothing matches
    if 0 < builtins.length names then builtins.isAttrs (builtins.getAttr entry elem."${head names}") else false;
  
  extraOptions = mkOption {
    type = with types; nullOr lines;
    default = "";
    example = ''
      snapshot_dir           btrbk_snapshots
    '';
    description = ''
      Extra options which influence how a backup is stored. See digint.ch/btrbk/doc/btrbk.conf.5.html under Options for more information.
    '';
  };
in
  let
    cfg = config.programs.btrbk;

    # map the sections part of the btrbk config into a the module
    volume_submodule =
      ({name, config, ... }:
      {
        options = {
          subvolumes = mkOption {
              # TODO enforce extra type checking
              type = with types; either (listOf path) (attrsOf lines);
              default = [];
              example = ''[ "/home/user/important_data" ]'';
              description = ''
                A list of subvolumes which should be backed up.
              '';
          };
          targets = mkOption {
            # TODO single argument syntactical sugar
            type = with types; either (listOf path) (attrsOf extraOptions);
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
      };
    };

    ###### implementation
    config = mkIf cfg.enable {
      environment.systemPackages = [ pkgs.btrbk ];
      # TODO add other attributes
      environment.etc."btrbk/btrbk.conf" = {
        source = pkgs.writeText "btrbk.conf"
          (( optionalString (cfg.extraOptions != null) cfg.extraOptions )
          + ((converter: (list2lines (map (pair: pair.name + "\n" + (list2lines (addPrefixes (converter pair.value.subvolumes)))) (setToNameValuePairs cfg.volumes))))
            (if (checkForSubAttrs cfg.volumes "subvolumes") then convertEntrys else convertLists)));
      };
    };
  }
