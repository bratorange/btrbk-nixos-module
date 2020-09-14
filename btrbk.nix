{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.btrbk;

  # map the sections part of the btrbk config into a the module
  volume_submodule =
    {name, config, ...}:
    {
      options = {
        subvolumes = mkOption {
            # TODO single argument syntactical sugar
            type = with types; listOf path;
            default = [];
            example = ''[ "/path/to/important/data" ]'';
            description = ''
              A list of subvolumes which should be backed up.
            '';
        };
        targets = mkOption {
          # TODO single argument syntactical sugar
          type = with types; listOf path;
          default = [];
          example = ''[ "/path/to/important/data" ]'';
          description = ''
            A list of targets where backups of this volume should be stored.
          '';
        };
      };
    };
in {
  options.programs.btrbk = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable the btrbk backup utility for btrfs based file systems.
      '';
    };
    extraConfig = mkOption {
      type = with types; nullOr lines;
      default = null;
      example = ''
        '';
    };
  };
  config = mkIf cfg.enable {
    environment.systemPackages = [ pkgs.btrbk ];
    environment.etc."btrbk/btrbk.conf" = {
      source = pkgs.writeText "btrbk.conf" ( optionalString (cfg.extraConfig != null) cfg.extraConfig);
    };
  };
}
