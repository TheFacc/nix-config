{
  description = "Manual T3 Code nightly launcher for NixOS (no boot service)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f system (
            import nixpkgs {
              inherit system;
            }
          )
        );

      runtimeInputsFor =
        pkgs: with pkgs; [
          nodejs_24
          python3
          gnumake
          gcc
          pkg-config
          git
          openssh
          coreutils
          bash
          curl
        ];

      # Mutable user dirs so T3 / provider CLIs can self-update. Nothing
      # provider-related is copied into the Nix store.
      npmRuntimeSetup = ''
        export npm_config_cache="''${npm_config_cache:-''${XDG_CACHE_HOME:-$HOME/.cache}/t3code-npm}"
        export npm_config_yes=true
        export npm_config_foreground_scripts=true
        export npm_config_update_notifier=false
        export npm_config_fund=false
        export npm_config_audit=false
        if command -v bash >/dev/null 2>&1; then
          SHELL="$(command -v bash)"
          export SHELL
          export npm_config_script_shell="$SHELL"
        fi
        export T3CODE_PROVIDER_PREFIX="''${T3CODE_PROVIDER_PREFIX:-''${XDG_DATA_HOME:-$HOME/.local/share}/t3code-providers}"
        export PATH="$T3CODE_PROVIDER_PREFIX/bin:$HOME/.local/bin:/run/current-system/sw/bin:$PATH"
      '';

      runT3 = ''
        # shellcheck disable=SC2016
        exec npm exec --yes --package=t3@nightly -- bash -c 'exec node "$(realpath "$(command -v t3)")" "$@"' t3 "$@"
      '';

      t3NightlyFunction = ''
        t3_nightly() {
          # shellcheck disable=SC2016
          npm exec --yes --package=t3@nightly -- bash -c 'exec node "$(realpath "$(command -v t3)")" "$@"' t3 "$@"
        }
      '';

      linkConnect = t3NightlyFunction + ''
        printf 'Refreshing T3 Connect link...\n' >&2
        t3_nightly connect link
      '';

      stopT3Function = ''
        stop_t3_server() {
          t3_runtime_file="''${T3CODE_HOME:-$HOME/.t3}/userdata/server-runtime.json"

          if [ ! -f "$t3_runtime_file" ]; then
            printf 'No T3 server runtime file found: %s\n' "$t3_runtime_file"
            return 0
          fi

          t3_pid="$(
            node -e 'const fs = require("fs"); const file = process.argv[1]; let pid = ""; try { const data = JSON.parse(fs.readFileSync(file, "utf8")); if (Number.isInteger(data.pid)) pid = String(data.pid); } catch {} process.stdout.write(pid);' "$t3_runtime_file"
          )"

          case "$t3_pid" in
            ""|*[!0-9]*)
              printf 'Runtime file has no valid numeric pid: %s\n' "$t3_runtime_file" >&2
              return 1
              ;;
          esac

          if ! kill -0 "$t3_pid" 2>/dev/null; then
            printf 'T3 server pid %s is not running.\n' "$t3_pid"
            return 0
          fi

          t3_cmd="$(ps -p "$t3_pid" -o args= 2>/dev/null || true)"
          case "$t3_cmd" in
            *"node_modules/@t3code/t3-"*" serve"*|*"node_modules/t3/bin/t3.js serve"*|*" t3 serve"*|*" t3.js serve"*)
              ;;
            *)
              printf 'Refusing to stop pid %s because it does not look like T3 serve:\n%s\n' "$t3_pid" "$t3_cmd" >&2
              return 1
              ;;
          esac

          printf 'Stopping T3 server pid %s...\n' "$t3_pid"
          kill "$t3_pid"

          i=0
          while kill -0 "$t3_pid" 2>/dev/null && [ "$i" -lt 40 ]; do
            sleep 0.25
            i=$((i + 1))
          done

          if kill -0 "$t3_pid" 2>/dev/null; then
            printf 'T3 server pid %s did not exit after 10 seconds.\n' "$t3_pid" >&2
            return 1
          fi

          printf 'Stopped T3 server pid %s.\n' "$t3_pid"
        }
      '';

      installNpmProviders = ''
        mkdir -p "$T3CODE_PROVIDER_PREFIX"
        npm install -g \
          --prefix "$T3CODE_PROVIDER_PREFIX" \
          --allow-scripts=@openai/codex \
          @openai/codex@latest \
          @anthropic-ai/claude-code@latest
      '';

      installCursor = ''
        if command -v cursor-agent >/dev/null 2>&1; then
          cursor-agent update
        else
          curl https://cursor.com/install -fsS | bash
        fi
      '';

      remoteHostSetup = ''
        resolve_t3_remote_host() {
          if [ -n "''${T3CODE_HOST:-}" ]; then
            printf '%s\n' "$T3CODE_HOST"
            return
          fi

          if command -v tailscale >/dev/null 2>&1; then
            local tailnet_ip
            tailnet_ip="$(tailscale ip -4 2>/dev/null | head -n 1 || true)"
            if [ -n "$tailnet_ip" ]; then
              printf '%s\n' "$tailnet_ip"
              return
            fi
          fi

          printf '0.0.0.0\n'
        }
      '';

      showProvider = ''
        show_provider() {
          local name="$1"
          if command -v "$name" >/dev/null 2>&1; then
            printf '%s (%s): ' "$name" "$(command -v "$name")"
            "$name" --version || true
          else
            printf '%s: not found\n' "$name"
          fi
        }
      '';
    in
    {
      packages = forAllSystems (
        system: pkgs:
        let
          runtimeInputs = runtimeInputsFor pkgs;

          mkT3Wrapper =
            name: command:
            pkgs.writeShellApplication {
              inherit name runtimeInputs;
              excludeShellChecks = [ "SC2016" ];
              text = npmRuntimeSetup + command;
            };
        in
        {
          default = self.packages.${system}.t3code-serve;

          t3code = mkT3Wrapper "t3code" runT3;

          t3code-serve = mkT3Wrapper "t3code-serve" (
            stopT3Function
            + ''
            stop_t3_server
            ''
            + remoteHostSetup
            + linkConnect
            + ''
            bind_host="''${T3CODE_BIND_HOST:-0.0.0.0}"
            tailnet_host="$(resolve_t3_remote_host)"
            if [ "$bind_host" = "0.0.0.0" ]; then
              printf 'Binding T3 Code to all interfaces on port %s.\n' "''${T3CODE_PORT:-3773}" >&2
              if [ "$tailnet_host" != "0.0.0.0" ]; then
                printf 'Tailnet URL: http://%s:%s\n' "$tailnet_host" "''${T3CODE_PORT:-3773}" >&2
              fi
            else
              printf 'Binding T3 Code to %s on port %s.\n' "$bind_host" "''${T3CODE_PORT:-3773}" >&2
            fi
            set -- serve --host "$bind_host" --port "''${T3CODE_PORT:-3773}" --no-browser "$@"
            ''
            + runT3
          );

          t3code-serve-local = mkT3Wrapper "t3code-serve-local" (
            linkConnect
            + ''
            set -- serve --no-browser "$@"
            ''
            + runT3
          );

          t3code-serve-raw = mkT3Wrapper "t3code-serve-raw" (
            ''
            set -- serve "$@"
            ''
            + runT3
          );

          t3code-remote = mkT3Wrapper "t3code-remote" (
            remoteHostSetup
            + ''
            host="$(resolve_t3_remote_host)"
            if [ "$host" = "0.0.0.0" ]; then
              printf 'Tailscale IP not found; binding all interfaces on port %s.\n' "''${T3CODE_PORT:-3773}" >&2
            else
              printf 'Binding T3 Code to Tailnet address %s on port %s.\n' "$host" "''${T3CODE_PORT:-3773}" >&2
            fi
            set -- serve --host "$host" --port "''${T3CODE_PORT:-3773}" --no-browser "$@"
            ''
            + runT3
          );

          t3code-lan = mkT3Wrapper "t3code-lan" (
            ''
            set -- serve --host "''${T3CODE_HOST:-0.0.0.0}" --port "''${T3CODE_PORT:-3773}" "$@"
            ''
            + runT3
          );

          t3code-connect = mkT3Wrapper "t3code-connect" (
            ''
            set -- connect "$@"
            ''
            + runT3
          );

          t3code-connect-link = mkT3Wrapper "t3code-connect-link" linkConnect;

          t3code-stop = mkT3Wrapper "t3code-stop" (
            stopT3Function
            + ''
            stop_t3_server
            ''
          );

          t3code-restart = mkT3Wrapper "t3code-restart" (
            stopT3Function
            + ''
            stop_t3_server
            ''
            + remoteHostSetup
            + linkConnect
            + ''
            bind_host="''${T3CODE_BIND_HOST:-0.0.0.0}"
            tailnet_host="$(resolve_t3_remote_host)"
            if [ "$bind_host" = "0.0.0.0" ]; then
              printf 'Binding T3 Code to all interfaces on port %s.\n' "''${T3CODE_PORT:-3773}" >&2
              if [ "$tailnet_host" != "0.0.0.0" ]; then
                printf 'Tailnet URL: http://%s:%s\n' "$tailnet_host" "''${T3CODE_PORT:-3773}" >&2
              fi
            else
              printf 'Binding T3 Code to %s on port %s.\n' "$bind_host" "''${T3CODE_PORT:-3773}" >&2
            fi
            set -- serve --host "$bind_host" --port "''${T3CODE_PORT:-3773}" --no-browser "$@"
            ''
            + runT3
          );

          t3code-status = mkT3Wrapper "t3code-status" (
            showProvider
            + ''
            t3_home="''${T3CODE_HOME:-$HOME/.t3}"

            printf 'T3 Code flake status\n'
            printf '====================\n'
            printf 'This is a local report from the flake launcher. It does not\n'
            printf 'reconfigure a server that is already running.\n'
            printf '\n'

            printf 'Data locations\n'
            printf '%s\n' '--------------'
            printf 'T3 home:        %s\n' "$t3_home"
            printf '                Chosen by T3 itself (env T3CODE_HOME, default ~/.t3).\n'
            printf '                Threads, Connect login, logs, worktrees live here.\n'
            printf '                This flake does not override it.\n'
            printf 'Providers:      %s\n' "$T3CODE_PROVIDER_PREFIX"
            printf '                Chosen by this flake (Codex + Claude npm prefix).\n'
            printf 'Cursor Agent:   %s/.local/bin and ~/.local/share/cursor-agent\n' "$HOME"
            printf '                Official Cursor installer, invoked by this flake.\n'
            if command -v tailscale >/dev/null 2>&1; then
              tailnet_ip="$(tailscale ip -4 2>/dev/null | head -n 1 || true)"
              printf 'Tailnet host:   %s\n' "''${tailnet_ip:-unavailable}"
              printf '                Used by nix run .#remote unless T3CODE_HOST is set.\n'
            else
              printf 'Tailnet host:   tailscale command not found\n'
            fi
            printf '\n'

            printf 'Provider CLIs on this command PATH\n'
            printf '%s\n' '----------------------------------'
            show_provider codex
            show_provider claude
            show_provider cursor-agent
            printf '\n'

            printf 'T3 Connect (from `t3 connect status`)\n'
            printf '%s\n' '-------------------------------------'
            npm exec --yes --package=t3@nightly -- bash -c 'exec node "$(realpath "$(command -v t3)")" "$@"' t3 connect status || true
            printf '\n'

            printf 'Leftover user systemd unit (not NixOS, not this flake)\n'
            printf '%s\n' '-----------------------------------------------------'
            if command -v systemctl >/dev/null 2>&1; then
              unit_enabled="$(systemctl --user is-enabled t3code.service 2>/dev/null || true)"
              unit_active="$(systemctl --user is-active t3code.service 2>/dev/null || true)"
              printf 'unit:     t3code.service (~/.config/systemd/user)\n'
              printf 'enabled:  %s  (disabled = will not start at next login/boot)\n' "''${unit_enabled:-unknown}"
              printf 'active:   %s  (active = a server is still running from that unit)\n' "''${unit_active:-unknown}"
              if [ "$unit_active" = active ]; then
                printf '\n'
                printf 'The live T3 process is still that systemd unit. It does not use\n'
                printf 'this flake PATH, so Codex/Claude stay invisible there until you\n'
                printf 'stop it and start: nix run .#serve\n'
              elif [ "$unit_enabled" = disabled ] || [ "$unit_enabled" = inactive ]; then
                printf 'Boot unit will not start. Use: nix run .#serve\n'
              fi
            else
              printf 'systemctl not found; cannot inspect t3code.service\n'
            fi
            printf '\n'
            printf 'Common commands\n'
            printf '%s\n' '---------------'
            printf 'Connect+direct: nix run .#serve      # relinks Connect, binds all interfaces, starts relay too\n'
            printf 'Restart serve:  nix run .#restart    # stops current T3 serve pid, relinks, starts again\n'
            printf 'Local relay:    nix run .#serve-local # relinks Connect, binds loopback only\n'
            printf 'Relink only:    nix run .#connect-link\n'
            printf 'Stop server:    nix run .#stop\n'
            printf 'Tailnet direct: nix run .#remote     # binds to tailscale ip when available\n'
            printf 'LAN direct:     nix run .#lan        # binds 0.0.0.0 unless T3CODE_HOST is set\n'
            printf 'Update CLIs:    nix run .#update     # mutable npm/user installs, not Nix store\n'
            ''
          );

          t3code-update = mkT3Wrapper "t3code-update" (
            installNpmProviders
            + installCursor
            + ''
            printf '\nRefreshing t3@nightly (used on the next serve process):\n'
            npm exec --yes --package=t3@nightly -- t3 --version
            printf '\nRestart nix run .#serve to pick up a new T3 nightly.\n'
            printf 'Provider CLIs in %s can also self-update from the T3 UI.\n' "$T3CODE_PROVIDER_PREFIX"
            ''
          );

          t3code-providers-install = mkT3Wrapper "t3code-providers-install" (
            installNpmProviders + installCursor
          );

          t3code-providers-update = mkT3Wrapper "t3code-providers-update" (
            installNpmProviders + installCursor
          );

          t3code-providers-status = mkT3Wrapper "t3code-providers-status" (
            showProvider
            + ''
            printf 'Provider prefix: %s\n' "$T3CODE_PROVIDER_PREFIX"
            printf 'PATH begins with: %s/bin and %s/.local/bin\n' "$T3CODE_PROVIDER_PREFIX" "$HOME"
            printf '\n'
            show_provider codex
            show_provider claude
            show_provider cursor-agent
            ''
          );

          t3code-disable-boot-service = mkT3Wrapper "t3code-disable-boot-service" ''
            if ! command -v systemctl >/dev/null 2>&1; then
              printf 'systemctl not found\n' >&2
              exit 1
            fi
            systemctl --user disable t3code.service
            printf 'Disabled t3code.service for future user sessions.\n'
            printf 'The current process was not stopped.\n'
          '';

          t3code-service-uninstall = mkT3Wrapper "t3code-service-uninstall" (
            ''
            printf 'This stops the running T3 server if the user unit is active.\n' >&2
            set -- service uninstall "$@"
            ''
            + runT3
          );
        }
      );

      apps = forAllSystems (
        system: _pkgs:
        let
          appFor =
            pkgName: description:
            {
              type = "app";
              program = "${self.packages.${system}.${pkgName}}/bin/${pkgName}";
              meta.description = description;
            };
        in
        {
          default = appFor "t3code-serve" "Start T3 Code (t3 serve) with flake provider PATH; use for T3 Connect";
          serve = appFor "t3code-serve" "Start T3 Code with T3 Connect and bind to the Tailnet IP when available";
          serve-local = appFor "t3code-serve-local" "Start T3 Code with T3 Connect on loopback only";
          serve-raw = appFor "t3code-serve-raw" "Start raw t3 serve without refreshing T3 Connect first";
          remote = appFor "t3code-remote" "Start t3 serve bound to the Tailscale IP when available";
          lan = appFor "t3code-lan" "Start t3 serve bound to T3CODE_HOST or 0.0.0.0 for LAN pairing";
          t3 = appFor "t3code" "Pass-through to t3@nightly with flake provider PATH";
          connect = appFor "t3code-connect" "t3 connect (login / unlink / status args)";
          connect-link = appFor "t3code-connect-link" "Refresh this environment's T3 Connect link";
          stop = appFor "t3code-stop" "Stop the T3 serve process recorded by T3's runtime file";
          restart = appFor "t3code-restart" "Stop current T3 serve, refresh Connect link, and start serve";
          status = appFor "t3code-status" "Show providers, T3 Connect, and leftover systemd unit state";
          update = appFor "t3code-update" "Update Codex, Claude Code, Cursor Agent, and refresh t3@nightly";
          providers-install = appFor "t3code-providers-install" "Install Codex, Claude Code, and Cursor Agent into mutable user locations";
          providers-update = appFor "t3code-providers-update" "Update Codex, Claude Code, and Cursor Agent in mutable user locations";
          providers-status = appFor "t3code-providers-status" "Show discovered provider CLI versions";
          disable-boot-service = appFor "t3code-disable-boot-service" "Disable leftover t3code.service without stopping a running process";
          service-uninstall = appFor "t3code-service-uninstall" "Uninstall the leftover T3 user service (stops the server)";
        }
      );

      devShells = forAllSystems (
        _system: pkgs: {
          default = pkgs.mkShell {
            packages = runtimeInputsFor pkgs;
            shellHook = npmRuntimeSetup + ''
              echo "T3 Code flake shell (manual serve, no boot unit)"
              echo "Start:     nix run .#serve"
              echo "Tailnet:   nix run .#remote"
              echo "LAN:       nix run .#lan"
              echo "Status:    nix run .#status"
              echo "Update:    nix run .#update"
              echo "Connect:   nix run .#connect"
              echo "Providers: already on PATH via $T3CODE_PROVIDER_PREFIX and ~/.local/bin"
            '';
          };
        }
      );
    };
}
