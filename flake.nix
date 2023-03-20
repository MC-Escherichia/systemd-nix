# SPDX-FileCopyrightText: 2020 Serokell <https://serokell.io>
#
# SPDX-License-Identifier: MPL-2.0

{
  description = "Generate systemd units from NixOS-style descriptions";

  outputs = { self, nixpkgs }: {

    lib = builtins.mapAttrs (_: pkgs: rec {
      generateSystemd = type: name: config:
        pkgs.writeText "${name}.${type}" (nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [{ systemd."${type}s".${name} = config; }];
        }).config.systemd.units."${name}.${type}".text;

      mkService = generateSystemd "service";

      mkUserService = name: config:
        pkgs.writeShellScriptBin "activate" ''
          set -euo pipefail
          export XDG_RUNTIME_DIR="/run/user/$UID"
	  if [ ! -f "/var/lib/systemd/linger/$USER" ]; then
		  loginctl enable-linger "$USER"
	  fi
          mkdir -p "$HOME/.config/systemd/user" "$HOME/.config/systemd/user/default.target.wants"
          rm -f -- "$HOME/.config/systemd/user/${name}.service" "$HOME/.config/systemd/user/default.target.wants/${name}.service"
          ln -s ${
            mkService name config
          } "$HOME/.config/systemd/user/${name}.service"
          ln -s "$HOME/.config/systemd/user/${name}.service" "$HOME/.config/systemd/user/default.target.wants"
          systemctl --user daemon-reload
          systemctl --user restart ${name}
        '';

       mkRootService = name: config: 
	pkgs.writeShellScriptBin "${name}-activate" ''
	  set -euo pipefail
	  rm -f -- "/usr/lib/systemd/system/${name}.service"
	  ln -s ${
	    mkService name config 
	  } "/usr/lib/systemd/user/${name}.service"
	  sudo systemctl daemon-reload
	  sudo systemctl enable ${name}
          sudo systemctl restart ${name}
        '';
    }) nixpkgs.legacyPackages;

    checks = builtins.mapAttrs (_: pkgs: {
      reuse = pkgs.runCommand "reuse-check" { buildInputs = [ pkgs.reuse ]; }
        "cd ${./.}; reuse lint && touch $out";
    }) nixpkgs.legacyPackages;

  };
}
