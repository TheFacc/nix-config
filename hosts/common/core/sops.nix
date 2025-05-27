{ inputs, config, ...}:
{
    imports = [
        inputs.sops-nix.nixosModules.sops
    ];

    sops = { # does not allow interpolating keys in the build step, cos that would be a security risk. You need to read the key from a file afterwords.
        defaultSopsFile = ./secrets/secrets.yaml;
        defaultSopsFormat = "yaml";
        validateSopsFiles = false;

        age = {
            # sshKeyPaths = [ "/home/facc/.ssh/id_rsa" ]; # automatically import host SSH keys as age keys
            # keyFile = /home/facc/.config/sopss/age/keys.txt; # this will use an age key that is expected to already be in the system
            keyFile = "/var/lib/sops-nix/keys.txt"; # this will use an age key that is expected to already be in the system
            generateKey = true; # generate a new key if the keyFile does not exist
        };

        # secrets = { # sudo cat /run/secrets/thiskeyname
        #     "nextcloud/adminpw" = {}; # facc
        #     "nextcloud/dbpw" = {};
        #     "nextcloud/secrets" = {};
        #     # "keys/ageTEST" = {
        #     #     # owner = config.users.users.facc.name; # will have access to the secret without sudo
        #     #     owner = "sometestsvc";
        #     #     group = "users";
        #     #     path = "/home/facc/.config/sopss/age/keys.txt";
        #     # };
        # };
    };
    # systemd.services."sometestsvc" = {
    #     script = ''
    #         echo "
    #         Hey bro! I'm a service, and imma send this secure password:
    #         $(cat ${config.sops.secrets."keys/ageTEST".path})
    #         located in:
    #         ${config.sops.secrets."keys/ageTEST".path}
    #         to database and hack the mainframe
    #         " > /var/lib/sometestsvc/testfile
    #     ''; # basic cat example. you can e.g. use it to fetch data using api. no explicit secret, just the path, so it's safe
    #     serviceConfig = {
    #     User = "sometestsvc"; # assign a new system user, defined below
    #     WorkingDirectory = "/var/lib/sometestsvc";
    #     };
    # };
    # users.users.sometestsvc = {
    #     home = "/var/lib/sometestsvc";
    #     createHome = true;
    #     isSystemUser = true;
    #     group = "sometestsvc";
    # };
    # users.groups.sometestsvc = { };
}