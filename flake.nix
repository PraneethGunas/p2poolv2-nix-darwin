{
  description = "P2Poolv2 node and Bitaxe miner on macOS, managed with nix-darwin";

  inputs = {
    # Deployment-specific values. Override with `--override-input local path:./local`.
    local = {
      url = "path:./local-example";
      flake = false;
    };
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    p2poolv2 = {
      url = "github:p2poolv2/p2poolv2";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Bitcoin Core PR #35861, the BIP 95 testnet5 reference implementation.
    bitcoin-testnet5 = {
      url = "github:fjahr/bitcoin/2026-07-t5-draft";
      flake = false;
    };
    mujina = {
      url = "github:256foundation/mujina";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      nix-darwin,
      ...
    }@inputs:
    let
      system = "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      darwinConfigurations.mac = nix-darwin.lib.darwinSystem {
        specialArgs = {
          inherit inputs;
          local = import inputs.local;
        };
        modules = [ ./hosts/mac ];
      };

      packages.${system} = {
        bitcoind-testnet5 = pkgs.callPackage ./pkgs/bitcoind-testnet5/package.nix {
          src = inputs.bitcoin-testnet5;
        };
        mujina = pkgs.callPackage ./pkgs/mujina/package.nix { src = inputs.mujina; };
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.deadnix
          pkgs.nixfmt
          pkgs.statix
        ];
      };

      formatter.${system} = pkgs.nixfmt;
    };
}
