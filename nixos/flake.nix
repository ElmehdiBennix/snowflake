{
  description = "Rambeau's modular NixOS systems: desktop and ThinkPad";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
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
      hostSystem = "x86_64-linux";
      stable = import nixpkgs-stable {
        system = hostSystem;
        config.allowUnfree = true;
      };

      commonSpecialArgs = {
        inherit stable zen-browser hermes-agent;
      };
    in
    {
      nixosConfigurations.desktop = nixpkgs.lib.nixosSystem {
        system = hostSystem;
        specialArgs = commonSpecialArgs;
        modules = [
          ./hosts/desktop/default.nix
          hermes-agent.nixosModules.default
        ];
      };

      nixosConfigurations.thinkpad = nixpkgs.lib.nixosSystem {
        system = hostSystem;
        specialArgs = commonSpecialArgs;
        modules = [
          ./hosts/thinkpad/default.nix
          hermes-agent.nixosModules.default
        ];
      };

      # Explicit stable-package helper. This is not a full NixOS system.
      packages.${hostSystem}.stable-hello = stable.hello;
    };
}
