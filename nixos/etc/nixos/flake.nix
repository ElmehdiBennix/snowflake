{
  description = "Rambeau's NixOS unstable system with a 26.05 stable fallback";

  inputs = {
    # Default package set and NixOS modules.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Explicit stable fallback channel for individual packages or a future stable system.
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Applications with upstream flake inputs.
    zen-browser.url = "github:0xc000022070/zen-browser-flake";
    hermes-agent.url = "github:NousResearch/hermes-agent";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-stable,
      zen-browser,
      hermes-agent,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
      stable = import nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit pkgs stable zen-browser hermes-agent;
        };

        modules = [
          ./hardware-configuration.nix
          ./configuration.nix
          hermes-agent.nixosModules.default
        ];
      };

      # Explicit stable-package helper. It is not a complete NixOS system.
      packages.${system}.stable-hello = stable.hello;
    };
}
