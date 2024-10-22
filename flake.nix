# A flake for the Specfm application. 

{
  description = "A Nix Flake for the Specfm application";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    shell-utils.url = "github:waltermoreira/shell-utils";
    intel-mpi.url = "github:Nixify-Technology/intel-mpi-nix";
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , shell-utils
    , intel-mpi
    }:

    flake-utils.lib.eachDefaultSystem (system:
    let
      # Standard nix packages
      pkgs = import nixpkgs {
        inherit system;
      };

      config = nixpkgs.lib.trivial.importJSON ./config.json;
      shell = shell-utils.myShell.${system};
      # mpi = pkgs.mpich;
      mpi =
        if config.tacc_execution then intel-mpi.packages.${system}.default else pkgs.mpich;

      src = pkgs.fetchFromGitHub
        {
          owner = "SPECFEM";
          repo = "specfem3d_globe";
          rev = "46dd8d685471e82bbac9cf4c3d60f4772a8b7971";
          hash = "sha256-S6MA1otYezoAuWOB6i2yKlWauy9QllWRXyJYVSBZPw8=";
          fetchSubmodules = true;
        };

      app = pkgs.stdenv.mkDerivation {
        name = "specfm";
        buildInputs = [
          pkgs.ps
          pkgs.gfortran
          mpi
        ];
        inherit src;

        buildPhase = ''
          mkdir -p $out/bin
          cp ${./config.json} $out/config.json
          ./configure --enable-vectorization MPIFC=mpif90 FC=gfortran CC=gcc 'FLAGS_CHECK=-O2 -mcmodel=medium -Wunused -Waliasing -Wampersand -Wcharacter-truncation -Wline-truncation -Wsurprising -Wno-tabs -Wunderflow' CFLAGS="-std=c99" && make all
          cp bin/* $out/bin
        '';
        phases = [ "unpackPhase" "buildPhase" ];
      };

      patchedApp = pkgs.stdenv.mkDerivation {
        name = "specfm";
        buildInputs = [
          pkgs.ps
          pkgs.gfortran
          pkgs.mpich
        ];
        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        runtimeDependencies = [ mpi ];
        inherit src;

        dontInstall = true;
        doDist = true;
        buildPhase = ''
          echo "Inside build phase..."
          mkdir -p $out/bin
          ./configure --enable-vectorization MPIFC=mpif90 FC=gfortran CC=gcc 'FLAGS_CHECK=-O2 -mcmodel=medium -Wunused -Waliasing -Wampersand -Wcharacter-truncation -Wline-truncation -Wsurprising -Wno-tabs -Wunderflow' CFLAGS="-std=c99" && make all
          cp bin/* $out/bin
          cp ${./config.json} $out/config.json
        '';
        distPhase = ''
          for f in $(ls $out/bin); do
            RPATH_OLD=$(patchelf --print-rpath $out/bin/$f)
            patchelf --set-rpath "${mpi}/lib:${mpi}/lib/release:$RPATH_OLD" $out/bin/$f
          done
          patchelf --add-rpath "${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.glibc}/lib" $out/bin/*
        '';
      };

    in
    {
      packages = {
        default = app;
        compiledApp = app;
        patchedApp = patchedApp;
      };
      devShells = {
        default = shell {
          name = "specfm";
          packages = [ mpi app pkgs.gfortran ];
        };
      };
    });

}


