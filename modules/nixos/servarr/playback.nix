{ lib, pkgs, ... }:

let
  apiKeyDirectory = "/run/recyclarr-api-keys";

  originalLanguageFormat = pkgs.writeText "playback-original-language.json" (
    builtins.toJSON {
      trash_id = "playback-original-language";
      name = "Playback Original Language";
      includeCustomFormatWhenRenaming = false;
      specifications = [
        {
          name = "Original Language";
          implementation = "LanguageSpecification";
          negate = false;
          required = true;
          fields.value = -2;
        }
      ];
    }
  );

  sonarrFormats = pkgs.linkFarm "recyclarr-sonarr-custom-formats" [
    {
      name = "playback-original-language.json";
      path = originalLanguageFormat;
    }
  ];

  radarrFormats = pkgs.linkFarm "recyclarr-radarr-custom-formats" [
    {
      name = "playback-original-language.json";
      path = originalLanguageFormat;
    }
  ];

  settingsFile = pkgs.writeText "recyclarr-settings.yml" (
    builtins.toJSON {
      resource_providers = [
        {
          name = "playback-sonarr-formats";
          type = "custom-formats";
          path = "${sonarrFormats}";
          service = "sonarr";
        }
        {
          name = "playback-radarr-formats";
          type = "custom-formats";
          path = "${radarrFormats}";
          service = "radarr";
        }
      ];
    }
  );

  profile = {
    name = "HD-1080p";
    upgrade.allowed = false;
  };

  h264 = id: {
    trash_ids = [ id ];
    assign_scores_to = [
      {
        name = profile.name;
        score = 100;
      }
    ];
  };

  originalAudio = {
    trash_ids = [ "playback-original-language" ];
    assign_scores_to = [
      {
        name = profile.name;
        score = 200;
      }
    ];
  };
in
{
  services.recyclarr = {
    enable = true;
    configuration = {
      sonarr.series = {
        base_url = "http://127.0.0.1:8989";
        api_key._secret = "${apiKeyDirectory}/sonarr";
        quality_profiles = [ profile ];
        custom_formats = [
          (h264 "cddfb4e32db826151d97352b8e37c648")
          originalAudio
        ];
      };

      radarr.movies = {
        base_url = "http://127.0.0.1:7878";
        api_key._secret = "${apiKeyDirectory}/radarr";
        quality_profiles = [ profile ];
        custom_formats = [
          (h264 "2899d84dc9372de3408e6d8cc18e9666")
          originalAudio
        ];
      };
    };
  };

  systemd.services.recyclarr-api-keys = {
    description = "Read Sonarr and Radarr API keys for Recyclarr";
    requires = [
      "sonarr.service"
      "radarr.service"
      "servarr-setup.service"
    ];
    after = [
      "sonarr.service"
      "radarr.service"
      "servarr-setup.service"
    ];
    before = [ "recyclarr.service" ];
    serviceConfig = {
      Type = "oneshot";
      RuntimeDirectory = "recyclarr-api-keys";
      RuntimeDirectoryMode = "0700";
      RuntimeDirectoryPreserve = "yes";
      UMask = "0077";
      ExecStart = "${lib.getExe pkgs.python3} ${./api_keys.py} ${apiKeyDirectory}";
    };
  };

  systemd.services.recyclarr = {
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    requires = [
      "recyclarr-api-keys.service"
      "sonarr.service"
      "radarr.service"
      "servarr-setup.service"
    ];
    after = [
      "network-online.target"
      "recyclarr-api-keys.service"
      "sonarr.service"
      "radarr.service"
      "servarr-setup.service"
    ];
    serviceConfig.UMask = "0077";
    preStart = lib.mkAfter ''
      ${lib.getExe' pkgs.coreutils "install"} -m 0600 ${settingsFile} /var/lib/recyclarr/settings.yml
    '';
  };

  services.restic.backups.b2.paths = [ "/var/lib/recyclarr/state" ];
}
