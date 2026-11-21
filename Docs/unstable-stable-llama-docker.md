# Unstable-first flake, stable fallback, Docker NVIDIA, and Hermes Agent

This system now has a stowed NixOS flake under:

```text
/home/rambeau/snowflake/nixos/etc/nixos/flake.nix
```

That directory is symlinked as:

```text
/etc/nixos -> /home/rambeau/snowflake/nixos/etc/nixos
```

The root `flake.nix` is not the source used for `/etc/nixos`. Only
`snowflake/nixos` is stowed into `/etc` in this dotfiles setup.

---

## Package channel policy

The default package source is nixpkgs unstable:

```nix
nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
```

An explicit stable fallback is pinned as `nixpkgs-stable`:

```nix
nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";
```

The fallback is available in `configuration.nix` as:

```nix
{ config, pkgs, stable, ... }:
```

Use a stable package only when needed:

```nix
stable.package-name
```

Examples:

```nix
environment.systemPackages = with pkgs; [
  bat
  fzf
  stable.neovim
];
```

For a full stable rebuild, copy or replace the `nixpkgs.url` input with
`nixos-26.05`, then run `nix flake update`. The stable input is intentionally
kept separate so unstable remains the default and stable packages remain easy
to test one at a time.

---

## Updating the stowed flake

Run all flake updates from the stowed directory:

```bash
cd /etc/nixos
nix flake update
```

Build without switching:

```bash
sudo nixos-rebuild build --flake /etc/nixos#nixos
```

Switch after reviewing the build:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

Update only one input:

```bash
nix flake lock --update-input nixpkgs
nix flake lock --update-input nixpkgs-stable
nix flake lock --update-input hermes-agent
nix flake lock --update-input zen-browser
```

The lock file is stored next to the configuration:

```text
/home/rambeau/snowflake/nixos/etc/nixos/flake.lock
```

Keep it in Git. It is the pinned record of the unstable/stable branches,
Hermes Agent, Zen Browser, and their transitive inputs.

---

## NVIDIA Docker support

Docker uses the NVIDIA Container Toolkit and CDI:

```nix
virtualisation.docker.enable = true;
hardware.nvidia-container-toolkit.enable = true;
```

After switching and rebooting, verify:

```bash
nvidia-smi
sudo docker run --rm --gpus all nvidia/cuda:12.9.1-base-ubuntu24.04 nvidia-smi
```

A valid container test should print the RTX 3090 and a CUDA/NVIDIA driver version.

If Docker cannot find a GPU, inspect:

```bash
systemctl restart docker
systemctl status nvidia-container-toolkit-cdi-generator
cat /var/run/cdi/nvidia.yaml
sudo docker info | grep -A6 -i runtimes
```

The Docker user has to be in the `docker` group. This machine already grants
that group to `rambeau`:

```nix
extraGroups = [ "networkmanager" "wheel" "docker" "libvirtd" "i2c" ];
```

Docker group membership is effectively host-root-equivalent. Keep it only while
Docker use requires it.

---

## Hermes Agent

Hermes Agent is imported into the NixOS configuration from the upstream flake:

```nix
hermes-agent.url = "github:NousResearch/hermes-agent";

modules = [
  ./hardware-configuration.nix
  ./configuration.nix
  hermes-agent.nixosModules.default
];
```

The native system-service configuration is:

```nix
services.hermes-agent = {
  enable = true;
  addToSystemPackages = true;

  settings = {
    model = {
      default = "llama/llama-swap";
      base_url = "http://127.0.0.1:9292/v1";
    };
    toolsets = [ "all" ];
  };

  backend = {
    mode = "dashboard";
    host = "127.0.0.1";
    port = 9119;
  };

  hermesHomeFiles = {
    "SOUL.md" =
      "You are a helpful local AI operator. Prefer local tools and never expose credentials.";
  };
};
```

Hermes is configured for local llama-swap rather than a hosted provider.
llama-swap must be listening on:

```text
http://127.0.0.1:9292/v1
```

The dashboard binds only to loopback:

```text
http://127.0.0.1:9119
```

Do not expose that dashboard to `0.0.0.0` without authentication and firewall
rules.

---

## Provider/key policy

Hermes can run with local llama-swap and normally does not need an API key.
Provider keys are only needed for hosted providers, web search, messaging
bridges, or optional tools.

Do not put provider keys in:

```nix
settings = {
  model = { };
};
```

The Hermes NixOS module expects secrets through `environmentFiles`:

```nix
services.hermes-agent.environmentFiles = [
  "/var/lib/hermes/env"
];
```

The plain env file can be protected with root-only permissions:

```bash
sudo install -d -m 700 -o hermes -g hermes /var/lib/hermes
sudo install -m 600 -o hermes -g hermes /dev/null /var/lib/hermes/env
sudoedit /var/lib/hermes/env
```

Example secret file:

```text
OPENROUTER_API_KEY=sk-or-your-key
ANTHROPIC_API_KEY=sk-ant-your-key
```

For reproducible encrypted secrets, use SOPS/Age. KeePassXC stores the human
vault; SOPS/Age is the decryption mechanism for a systemd service.

A future SOPS setup would look like:

```nix
services.hermes-agent.environmentFiles = [
  config.sops.secrets."hermes-env".path
];
```

Never place a secret in `flake.nix`, `configuration.nix`, Git, or the Nix store.

---

## llama.cpp and llama-swap

llama.cpp and llama-swap are installed from unstable nixpkgs:

```nix
llama-cpp-vulkan
llama-swap
```

Their binaries are:

```bash
llama-server --help
llama-swap --help
```

Create a llama-swap config, for example `/etc/llama-swap/config.yaml`, and start
a user/system service that points llama-swap at the GGUF model directory.

A llama-swap endpoint must offer an OpenAI-compatible API at `/v1`.

Before starting Hermes:

```bash
curl http://127.0.0.1:9292/v1/models
```

The request should return at least one model. Then start/verify Hermes:

```bash
systemctl status hermes-agent
journalctl -u hermes-agent -f
hermes --version
```

The dashboard will be available at:

```text
http://127.0.0.1:9119
```

---

## Applying the configuration

Save work, then switch with the stowed flake:

```bash
cd /etc/nixos
sudo nixos-rebuild switch --flake .#nixos
```

A safer two-step process is:

```bash
sudo nixos-rebuild build --flake /etc/nixos#nixos
sudo nixos-rebuild switch --flake /etc/nixos#nixos
```

NixOS generations remain available in systemd-boot for rollback:

```bash
sudo nixos-rebuild switch --rollback
```

To run a known-good 26.05 package instead of unstable, add it with the
`stable` argument in `configuration.nix`, rather than replacing the whole
system package set. This preserves a Nix-native fallback while keeping unstable
as the default.

---

## Verification

```bash
# Unstable/stable flake pins
nix flake metadata /etc/nixos

# NVIDIA Docker
nvidia-smi
sudo docker run --rm --gpus all nvidia/cuda:12.9.1-base-ubuntu24.04 nvidia-smi

# llama-swap
curl http://127.0.0.1:9292/v1/models
llama-server --help
llama-swap --help

# Hermes
systemctl status hermes-agent
journalctl -u hermes-agent -f
hermes --version
curl http://127.0.0.1:9119
```

The system should only be considered complete after both Docker GPU passthrough
and llama-swap are verified. Hermes should remain loopback-bound until secrets,
authentication, and firewall behavior are reviewed.
