{
  description = "Tiny Tapeout ASIC & Gowin FPGA SystemVerilog DevShell";

  nixConfig = {
    extra-substituters = [
      "https://nix-cache.fossi-foundation.org"
    ];
    extra-trusted-public-keys = [
      "nix-cache.fossi-foundation.org:3+K59iFwXqKsL7BNu6Guy0v+uTlwsxYQxjspXzqLYQs="
    ];
  };

  inputs = {
    nixpkgs.url = "https://channels.nixos.org/nixos-unstable/nixexprs.tar.zst";
    flake-utils.url = "github:numtide/flake-utils";

    nix-eda.url = "github:fossi-foundation/nix-eda";
    nix-eda-431.url = "github:fossi-foundation/nix-eda/4.3.1";
    librelane.url = "github:librelane/librelane";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      nix-eda,
      nix-eda-431,
      librelane,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        edaPkgs = nix-eda.packages.${system};
        edaPkgs431 = nix-eda-431.packages.${system};
        librelanePkgs = librelane.packages.${system};
        lib = pkgs.lib;

        isLinux = pkgs.stdenv.hostPlatform.isLinux;

        pythonEnv = pkgs.python3.withPackages (
          ps: with ps; [
            apycula
            amaranth
            migen
            cocotb
            cocotb-bus
            pytest
            pyserial
            pyyaml
            click
            chevron
            svgwrite
            gdstk
            cairosvg
            rich
            requests
          ]
        );
      in
      {
        devShells = {
          default = pkgs.mkShell {
            name = "eda-shell";

            packages = [
              edaPkgs.yosysFull
              edaPkgs.yosys-sby
              edaPkgs.yosys-eqy
              edaPkgs.kepler-formal
              edaPkgs.magic
              edaPkgs.netgen
              edaPkgs.klayout
              edaPkgs.klayout-gdsfactory
              edaPkgs.xschem
              edaPkgs.openvaf-r
              edaPkgs.verilator
              pkgs.iverilog
              edaPkgs.gtkwave

              librelanePkgs.default
              librelanePkgs.openroad
              pythonEnv

              pkgs.ngspice
              pkgs.z3
              pkgs.bitwuzla
              pkgs.surfer
              pkgs.sv-lang
              pkgs.verible
              pkgs.svls
              pkgs.nextpnr
              pkgs.openfpgaloader
              pkgs.openocd
              pkgs.gnumake
              pkgs.cmake
              pkgs.ninja
              pkgs.git
              pkgs.slang-server
            ]
            ++ lib.optionals isLinux [
              edaPkgs.xyce
            ];

            shellHook = ''
              export PDK_ROOT="$PWD/.pdk"
              export PDK="sky130A"
            '';
          };

          sky130-pcells = pkgs.mkShell {
            name = "sky130-pcells";
            packages = [
              edaPkgs431.klayout-gdsfactory
            ];
          };
        };
      }
    );
}
