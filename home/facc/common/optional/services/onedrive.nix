# { user, pkgs, config, lib, ... }:
{
    home.file.".config/onedrive/sync_list".text = ''
        # The ordering of entries is highly recommended - exclusions before inclusions
        # Exclude
        !/5.2_PACS/22-23/dont_sync
        !/5.2_PACS/22-23/Lectures
        !/5.2_PACS/22-23/Challenges
        !/5.2_PACS/22-23/Proj/ORB_SLAM3_Lux
        !/5.2_PACS/22-23/Proj/SLAMoCaDO/.git
        !/5.2_PACS/22-23/Proj/SLAMoCaDO/.cache
        !/5.2_PACS/22-23/Proj/SLAMoCaDO/build
        !/5.2_PACS/22-23/Proj/SLAMoCaDO/lib
        !/5.2_PACS/22-23/Proj/SLAMoCaDO/ThirdParty/DBoW2/build
        !/5.2_PACS/22-23/Proj/SLAMoCaDO/ThirdParty/DBoW2/lib
        !/5.2_PACS/22-23/Proj/SLAMoCaDO/ThirdParty/g2o/build
        !/5.2_PACS/22-23/Proj/SLAMoCaDO/ThirdParty/g2o/lib
        !/5.2_PACS/22-23/Proj/SLAMoCaDO/ThirdParty/Sophus/build

        # Include
        /scazzo/walls
        /5.2_PACS/22-23
    '';
}
