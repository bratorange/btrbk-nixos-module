let
  btrfsRoot = "/run/important_files";
  backupDir = "/run/backup";
  snapshotDir = "snapshots";
  dataDir = "data";
  testData = "testdata";
in
  import <nixpkgs/nixos/tests/make-test-python.nix> {
   machine = 
    { config, pkgs, ... }:
    {
      imports = [ ./btrbk.nix ];
  
      environment.systemPackages = with pkgs; [ btrfs-progs ];
      programs.btrbk = {
        enable = true;
        extraOptions =''
          snapshot_dir  ${snapshotDir}
        '';
          volumes."${btrfsRoot}" = {
            subvolumes = [ dataDir ];
            targets = [ backupDir ];
          };
      };
    };
  
    testScript =
      ''
        # create the btrfs pool which will simulate our important data
        machine.succeed("dd if=/dev/zero of=/data_fs bs=120M count=1")
        machine.succeed("mkfs.btrfs /data_fs")
        machine.succeed("mkdir -p ${btrfsRoot}")
        machine.succeed("mount /data_fs ${btrfsRoot}")
        machine.succeed("btrfs subvolume create ${btrfsRoot}/${snapshotDir}")
        machine.succeed("btrfs subvolume create ${btrfsRoot}/${dataDir}")

        # create the btrfs pool which will be functioning as a backup repo
        machine.succeed("dd if=/dev/zero of=/backup_fs bs=120M count=1")
        machine.succeed("mkfs.btrfs /backup_fs")
        machine.succeed("mkdir -p ${backupDir}")
        machine.succeed("mount /backup_fs ${backupDir}")

        machine.succeed("cat /etc/btrbk/btrbk.conf 1>&2")
        machine.succeed("echo ${testData} > ${btrfsRoot}/${dataDir}/testfile")
        
        machine.succeed("btrbk --Version")
        machine.succeed("btrbk run 1>&2")

        output = machine.succeed("cat ${backupDir}/${dataDir}*/*")
        if "${testData}" == output:
            raise Exception("backup didnt work")
      '';
  }
