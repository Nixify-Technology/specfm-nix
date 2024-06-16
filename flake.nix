# A flake for the Specfm application. 

{
  description = "A Nix Flake for the Specfm application";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    intel-mpi.url = "github:Nixify-Technology/intel-mpi-nix";

  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , intel-mpi
    }:

    flake-utils.lib.eachDefaultSystem (system:
    let
      # Standard nix packages
      pkgs = import nixpkgs {
        inherit system;
      };

      mpi = intel-mpi.packages.${system}.default;

      hdf5 = pkgs.stdenv.mkDerivation
        {
          name = "hdf5";
          buildInputs = [
            pkgs.ps
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
            source ${mpi}/env/vars.sh
            mkdir -p $out/hdf5
            CC=mpicc FC=mpif90 ./configure --enable-fortran --enable-parallel --prefix=$out/hdf5 --enable-shared --enable-static
            make -j12
            make install

          '';
          phases = [ "unpackPhase" "buildPhase" ];
        };
      # app = pkgs.stdenv.mkDerivation {
      #   name = "specfm";
      #   installPhase = ''
      #     mkdir -p $out;
      #     cp ${intel-mpi} $out
      #   '';
      # };

    in
    rec {
      packages = {
        default = hdf5;
      };
    });

}


