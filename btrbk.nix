{ config, lib, pkgs, ... }:

with lib;
with import ./btrbkHelpers.nix;

let
  cfg = config.programs.btrbk;
  btrbkOptions = import ./btrbkOptions.nix {inherit config lib pkgs;};

  optionSections = {
    global = {inherit (btrbkOptions) snapshotDir extraOptions timestampFormat snapshotCreate incremental noauto preserveDayOfWeek sshUser sshIdentity sshCompression;};

    subvolume = {inherit (btrbkOptions) snapshotDir extraOptions timestampFormat snapshotName snapshotCreate incremental noauto preserveDayOfWeek sshUser sshIdentity sshCompression;};

    target = {inherit (btrbkOptions) extraOptions incremental noauto preserveDayOfWeek sshUser sshIdentity sshCompression;};

    volume = {inherit (btrbkOptions) snapshotDir extraOptions timestampFormat snapshotCreate incremental noauto preserveDayOfWeek sshUser sshIdentity sshCompression;};
  };

  convertEntrys =
    subentry: subentryType: builtins.concatLists (
      map (entry: [(subentryType + " " + entry)] ++ (addPrefixes (renderOptions subentry."${entry}")))
      (builtins.attrNames subentry));
  
  convertLists =
    subentry: subentryType: map (entry: subentryType + " " + entry) subentry;

  convertString =
    subentry: subentryType: [ (subentryType + " " + subentry) ];

  renderVolumes = builtins.concatLists (
    mapAttrsToList (name: value: 
      # volume head line
      [ ("volume " + name) ]
      # volume options
      ++ (addPrefixes (renderOptions value)) 
      # volume subvolumes which should be backed up
      ++ (renderSubsection value "subvolume") 
      # volume backup targets
      ++ (renderSubsection value "target"))
    cfg.volumes);

  renderSubsection =
    volumeEntry: subsectionType:
      let 
        subsectionEntry = builtins.getAttr (subsectionType + "s") volumeEntry;
        converter =
          # differentiate whether a simple list is used, or if extra options a used for the subentry
          if (builtins.isAttrs subsectionEntry) then convertEntrys else convertLists;
      in
        (addPrefixes (converter subsectionEntry subsectionType));

        subsectionDataType = options: with types; either (listOf str) (attrsOf (submodule
          ({name, config, ...}:
          {
            inherit options;
          }))
        );

  # renderOptions :: attrs -> list
  renderOptions = options:
  with builtins; concatLists (attrValues 
    (filterAttrs (name: value: builtins.hasAttr name btrbkOptions) options)
  );


  # map the sections part of the btrbk config into a the module
  volumeSubmodule =
    ({name, config, ... }:
    {
      options = {
        subvolumes = mkOption {
            type = subsectionDataType optionSections.subvolume;
            default = [];
            example = [ "/home/user/important_data" "/mount/even_more_important_data"];
            description = "A list of subvolumes which should be backed up.";
        };
        targets = mkOption {
          # TODO check if target rarely has any config options
          type = subsectionDataType optionSections.target;
          default = [];
          example = ''[ "/mount/backup_drive" ]'';
          description = "A list of targets where backups of this volume should be stored.";
        };
      } // optionSections.volume;
  });
  in {
    options.programs.btrbk = ({
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the btrbk backup utility for btrfs based file systems.";
      };
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
    } // optionSections.global);

    ###### implementation
    config = mkIf cfg.enable {
      environment.systemPackages = [ pkgs.btrbk ];
      environment.etc."btrbk/btrbk.conf" = {
        source = pkgs.writeText "btrbk.conf"
          ( (list2lines (renderOptions cfg))
            + (list2lines renderVolumes));
      };
    };
  }
