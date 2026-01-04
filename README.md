# all

Run commands on all your NixOS/Darwin hosts in parallel using [mprocs](https://github.com/pvolok/mprocs).

Dynamically discovers hosts from any flake by evaluating `nixosConfigurations` and `darwinConfigurations`.

**Requires SSH access to all target machines** (e.g., via `~/.ssh/config`, SSH agent, or Tailscale).

<video src="https://github.com/multivac61/all.nix/releases/download/v0.1.0/all.mp4" controls width="100%"></video>

## Usage

```bash
# Run from any flake directory with nixosConfigurations/darwinConfigurations
cd ~/my-nixos-config
all uptime
all --nixos 'systemctl status'
all --darwin 'nix run nixpkgs#fastfetch'

# Point to a different flake
all --flake github:user/config uptime

# Or specify hosts manually
all --hosts server1,server2 'df -h'

# Custom user and domain (e.g., for Tailscale)
all --user admin --domain tail0123.ts.net uptime

# Preview commands without running
all --dry-run uptime
```

## Options

| Option | Description |
|--------|-------------|
| `-h, --help` | Show help message |
| `--hosts h1,h2,...` | Specify hosts manually (comma-separated) |
| `--flake <path>` | Path to flake (default: current directory) |
| `--nixos` | Only run on NixOS hosts |
| `--darwin` | Only run on Darwin hosts |
| `--user <user>` | SSH user (default: root) |
| `--domain <domain>` | Domain suffix (e.g., `tail0123.ts.net`) |
| `--dry-run` | Show commands without executing |

## Installation

```bash
# Run directly
nix run github:multivac61/all.nix -- uptime

# Or add to your flake
{
  inputs.all.url = "github:multivac61/all.nix";
}
```
