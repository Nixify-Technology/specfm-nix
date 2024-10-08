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

      shell = shell-utils.myShell.${system};
      mpi = intel-mpi.packages.${system}.default;

      hdf5 = pkgs.stdenv.mkDerivation
        {
          name = "hdf5";
          buildInputs = [
            pkgs.ps
            pkgs.gfortran
            pkgs.mpich
          ];
          nativeBuildInputs = [
            pkgs.breakpointHook

          ];
          src = pkgs.fetchzip
            {
              url = "https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.13/hdf5-1.13.3/src/hdf5-1.13.3.tar.gz";
              hash = "sha256-+QHhzaPwagWQebOUXElC+J80NXH0lugYPoizRCYOAlA=";
            };
          buildPhase = ''
            echo "Inside buildPhase.."
            
            mkdir -p $out/hdf5
            CC=mpicc FC=mpif90 ./configure --enable-fortran --enable-parallel --prefix=$out/hdf5 --enable-shared --enable-static
            make -j12
            make install

          '';
          phases = [ "unpackPhase" "buildPhase" ];
        };

      app = pkgs.stdenv.mkDerivation {
        name = "specfm";
        buildInputs = [
          pkgs.ps
          pkgs.gfortran
          pkgs.mpich
        ];
        # Attempt to "force" linking in intel-mpi;
        #  cf., https://nixos.org/manual/nixpkgs/stable/#setup-hook-autopatchelfhook
        nativeBuildInputs = [ pkgs.autoPatchelfHook ];
        runtimeDependencies = [ mpi ];
        src = pkgs.fetchFromGitHub
          {
            owner = "SPECFEM";
            repo = "specfem3d_globe";
            rev = "46dd8d685471e82bbac9cf4c3d60f4772a8b7971";
            hash = "sha256-S6MA1otYezoAuWOB6i2yKlWauy9QllWRXyJYVSBZPw8=";
            fetchSubmodules = true;
          };

        buildPhase = ''
          echo "Inside build phase..."
          mkdir -p $out/bin
          ./configure --enable-vectorization MPIFC=mpif90 FC=gfortran CC=gcc 'FLAGS_CHECK=-O2 -mcmodel=medium -Wunused -Waliasing -Wampersand -Wcharacter-truncation -Wline-truncation -Wsurprising -Wno-tabs -Wunderflow' CFLAGS="-std=c99" && make all
          cp bin/* $out/bin
        '';
        phases = [ "unpackPhase" "buildPhase" ];
      };

    in
    {
      packages = {
        default = app;
      };
      devShells = {
        default = shell {
          name = "specfm";
          packages = [ hdf5 app pkgs.gfortran ];
        };
      };
    });

}


