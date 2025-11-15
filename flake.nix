{
  description = "asl-xdsl";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, uv2nix, pyproject-nix, pyproject-build-systems, ... }:
    let
      inherit (nixpkgs) lib;
      
      forAllSystems = lib.genAttrs [
        "x86_64-linux"
        "aarch64-linux"
      ];
      
    in {
      packages = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          
          workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
          
          overlay = workspace.mkPyprojectOverlay {
            sourcePreference = "wheel";
          };
          
          python = pkgs.python313;
          
          pythonSet = (pkgs.callPackage pyproject-nix.build.packages {
            inherit python;
          }).overrideScope (lib.composeManyExtensions [
            pyproject-build-systems.overlays.default
            overlay
          ]);
          
        in {
          default = pythonSet.mkVirtualEnv "asl-xdsl-env" workspace.deps.default;
          
          asl-xdsl = pythonSet.mkVirtualEnv "asl-xdsl-env" workspace.deps.default;
        }
      );
      
      devShells = forAllSystems (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          
          workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };
          
          overlay = workspace.mkPyprojectOverlay {
            sourcePreference = "wheel";
          };
          
          python = pkgs.python311;
          
          pythonSet = (pkgs.callPackage pyproject-nix.build.packages {
            inherit python;
          }).overrideScope (lib.composeManyExtensions [
            pyproject-build-systems.overlays.default
            overlay
          ]);
          
          venv = pythonSet.mkVirtualEnv "asl-xdsl-dev-env" workspace.deps.all;
          
        in {
          default = pkgs.mkShell {
            packages = [
              venv
              pkgs.uv
              pkgs.llvmPackages_21.mlir
              pkgs.llvmPackages_21.llvm
            ];
          };
          
          runtime = pkgs.mkShell {
            packages = [
              (pythonSet.mkVirtualEnv "asl-xdsl-runtime-env" workspace.deps.default)
              pkgs.llvmPackages_21.mlir
              pkgs.llvmPackages_21.llvm
            ];
          };
        }
      );
    };
}