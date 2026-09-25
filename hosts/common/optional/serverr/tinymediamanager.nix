# I made a flake at https://github.com/TheFacc/tinyMediaManager-flake
# but the native version does not have webui... weird. So I must use the container for remote access:
let
    user = "facc";
    svcName = "tinyMediaManager";
in
{
#     # Make sure storage is ready first
#     imports = [
#         (import ./automount.nix {
#         extraOptions = [ "x-systemd.before=podman-tinyMediaManager.service" ];
#         })
#     ];
    systemd.services."podman-${svcName}" = {
        after = [ "mnt-mediapool-mainet.mount" ];
        requires = [ "mnt-mediapool-mainet.mount" ];
        wantedBy = [ "mnt-mediapool-mainet.mount" ]; # start again when the pool comes back
    };

    # TMM
    virtualisation = {
        podman.enable = true;
    #     setSocketVariable = true;
#         dockerCompat = true;  # Optional: enables `docker` command as an alias to podman
#         rootless.enable = true;

        oci-containers = {
            backend = "podman";

            containers."${svcName}" = {
                image = "tinymediamanager/tinymediamanager:5.1.6"; # might drop support for multi-version episodes in 5.2.0
                ports = [
                    "4000:4000"
                ];
                volumes = [
                    "/home/${user}/tmm-config:/data"
                    "/mnt/mediapool/mainet:/media/pool/mainet" # the pool itself, same paths inside as before
                    "/mnt/ssd512/mainet:/media/ssd512"
                ];
#                environment = {}; # Optional env vars, if TMM needs any
                # user = user; # wrong: your user is not inside the container.
                autoStart = true;
#                restartPolicy = "always"; # \ne
            };
        };

        # Optional: Allow linger so user services run at boot
#        systemd.user.services.docker.enable = true;
    };
}