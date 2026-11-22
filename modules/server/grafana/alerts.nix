{ config, ... }:
let
  inherit (config.sops) placeholder;
  backupRule = uid: title: expression: noDataState: {
    inherit uid title noDataState;
    condition = "B";
    for = "2m";
    execErrState = "Error";
    annotations.summary = title;
    data = [
      {
        refId = "A";
        datasourceUid = "prometheus";
        relativeTimeRange = {
          from = 600;
          to = 0;
        };
        model = {
          refId = "A";
          expr = expression;
          instant = true;
          range = false;
        };
      }
      {
        refId = "B";
        datasourceUid = "__expr__";
        relativeTimeRange = {
          from = 0;
          to = 0;
        };
        model = {
          refId = "B";
          datasource = {
            type = "__expr__";
            uid = "__expr__";
          };
          type = "threshold";
          expression = "A";
          conditions = [
            {
              type = "query";
              query.params = [ "B" ];
              evaluator = {
                type = "gt";
                params = [ 0 ];
              };
              operator.type = "and";
              reducer.type = "last";
            }
          ];
        };
      }
    ];
  };
in
{
  sops.secrets."grafana/telegram-bot-token" = { };
  sops.secrets."grafana/telegram-chat-id" = { };
  sops.templates."grafana-telegram.yaml" = {
    owner = "grafana";
    restartUnits = [ "grafana.service" ];
    content = builtins.toJSON {
      apiVersion = 1;
      contactPoints = [
        {
          orgId = 1;
          name = "Telegram";
          receivers = [
            {
              uid = "pi5-telegram";
              type = "telegram";
              settings = {
                bottoken = placeholder."grafana/telegram-bot-token";
                chatid = placeholder."grafana/telegram-chat-id";
              };
            }
          ];
        }
      ];
    };
  };
  services.grafana.provision.alerting = {
    contactPoints.path = config.sops.templates."grafana-telegram.yaml".path;
    policies.settings = {
      apiVersion = 1;
      policies = [
        {
          orgId = 1;
          receiver = "Telegram";
          group_by = [ "alertname" ];
        }
      ];
    };
    rules.settings = {
      apiVersion = 1;
      groups = [
        {
          orgId = 1;
          name = "Daily backup";
          folder = "pi5";
          interval = "1m";
          rules = [
            (backupRule "restic-b2-failed" "pi5 backup failed"
              ''pi5_backup_last_run_success{job="pi5"} == bool 0''
              "OK"
            )
            # allow a long backup and the 25-hour day when daylight saving time ends
            (backupRule "restic-b2-overdue" "pi5 backup overdue"
              ''time() - (pi5_backup_last_success_timestamp_seconds{job="pi5"} or on(instance) node_textfile_mtime_seconds{job="pi5",file=~".*restic-b2-start[.]prom"}) - 26 * 3600''
              "Alerting"
            )
          ];
        }
      ];
    };
  };
}
