{
  description = "Run commands on all your NixOS/Darwin hosts in parallel - dynamically discovers hosts from any flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs?ref=nixos-unstable&shallow=1";

  outputs =
    { nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;
      forAllSystems = lib.genAttrs lib.systems.flakeExposed;
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.writeShellApplication {
            name = "all";
            runtimeInputs = with pkgs; [
              mprocs
              openssh
              jq
              nix
            ];
            text = ''
              get_hosts() {
                local flake_path="$1"
                local config_type="$2"
                nix eval "$flake_path#$config_type" --apply 'builtins.attrNames' --json 2>/dev/null | jq -r '.[]' || true
              }

              usage() {
                local nixos_hosts darwin_hosts
                nixos_hosts=$(get_hosts "." "nixosConfigurations" | tr '\n' ' ')
                darwin_hosts=$(get_hosts "." "darwinConfigurations" | tr '\n' ' ')

                echo "Usage: all [options] <command>"
                echo "Runs <command> on hosts in parallel using mprocs"
                echo ""
                echo "Options:"
                echo "  -h, --help           Show this help message"
                echo "  --hosts h1,h2,...    Specify hosts (comma-separated)"
                echo "  --flake <path>       Path to flake (default: current directory)"
                echo "  --nixos              Only run on NixOS hosts"
                echo "  --darwin             Only run on Darwin hosts"
                echo "  --user <user>        SSH user (default: root)"
                echo "  --domain <domain>    Domain suffix (e.g., tail0123.ts.net)"
                echo "  --dry-run            Show commands without executing"
                echo ""
                echo "Detected hosts in current flake:"
                echo "  NixOS:  ''${nixos_hosts:-none}"
                echo "  Darwin: ''${darwin_hosts:-none}"
                echo ""
                echo "Examples:"
                echo "  all uptime"
                echo "  all --hosts server1,server2 'df -h'"
                echo "  all --nixos 'nixos-rebuild switch'"
                echo "  all --user admin --domain example.com uptime"
                echo "  all --dry-run uptime"
              }

              if [ $# -eq 0 ]; then
                usage
                exit 1
              fi

              HOSTS=""
              FILTER=""
              FLAKE_PATH="."
              USER="root"
              DOMAIN=""
              DRY_RUN=false
              REMOTE_PATH="PATH=/run/current-system/sw/bin:\$PATH"

              while [ $# -gt 0 ]; do
                case "$1" in
                  -h|--help)
                    usage
                    exit 0
                    ;;
                  --hosts)
                    shift
                    HOSTS="''${1//,/ }"
                    shift
                    ;;
                  --flake)
                    shift
                    FLAKE_PATH="$1"
                    shift
                    ;;
                  --nixos)
                    FILTER="nixosConfigurations"
                    shift
                    ;;
                  --darwin)
                    FILTER="darwinConfigurations"
                    shift
                    ;;
                  --user)
                    shift
                    USER="$1"
                    shift
                    ;;
                  --domain)
                    shift
                    DOMAIN=".$1"
                    shift
                    ;;
                  --dry-run)
                    DRY_RUN=true
                    shift
                    ;;
                  *)
                    break
                    ;;
                esac
              done

              if [ $# -eq 0 ]; then
                echo "Error: No command specified"
                usage
                exit 1
              fi

              CMD="$*"

              # Get hosts from flake if not specified via --hosts
              if [ -z "$HOSTS" ]; then
                if [ -n "$FILTER" ]; then
                  HOSTS=$(get_hosts "$FLAKE_PATH" "$FILTER" | tr '\n' ' ')
                else
                  nixos=$(get_hosts "$FLAKE_PATH" "nixosConfigurations" | tr '\n' ' ')
                  darwin=$(get_hosts "$FLAKE_PATH" "darwinConfigurations" | tr '\n' ' ')
                  HOSTS="$nixos $darwin"
                fi
              fi

              # Trim whitespace
              HOSTS=$(echo "$HOSTS" | xargs)

              if [ -z "$HOSTS" ]; then
                echo "Error: No hosts found. Use --hosts or run from a flake directory."
                exit 1
              fi

              # Build mprocs arguments dynamically
              MPROCS_ARGS=()
              for h in $HOSTS; do
                MPROCS_ARGS+=("ssh -At $USER@$h$DOMAIN '$REMOTE_PATH $CMD; exec bash'")
              done

              if [ "$DRY_RUN" = true ]; then
                echo "Would run:"
                printf '  %s\n' "''${MPROCS_ARGS[@]}"
                exit 0
              fi

              exec mprocs "''${MPROCS_ARGS[@]}"
            '';
          };
        }
      );
    };
}
