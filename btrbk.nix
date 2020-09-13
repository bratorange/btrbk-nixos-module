{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.btrbk;
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
