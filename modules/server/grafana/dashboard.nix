let
  datasource = {
    type = "prometheus";
    uid = "prometheus";
  };
  graph = id: title: unit: expr: legendFormat: x: y: {
    inherit id title datasource;
    type = "timeseries";
    gridPos = {
      inherit x y;
      w = 12;
      h = 8;
    };
    fieldConfig.defaults = {
      inherit unit;
      min = 0;
    };
    targets = [
      {
        inherit expr legendFormat;
        refId = "A";
      }
    ];
  };
in
{
  uid = "pi5";
  title = "pi5";
  schemaVersion = 39;
  editable = true;
  refresh = "1m";
  time = {
    from = "now-6h";
    to = "now";
  };

  panels = [
    {
      id = 1;
      title = "Services";
      type = "table";
      inherit datasource;
      gridPos = {
        x = 0;
        y = 0;
        w = 24;
        h = 10;
      };
      targets = [
        {
          refId = "A";
          instant = true;
          range = false;
          format = "table";
          # absent probes are unknown, and sites without probes still have shortcuts
          expr = ''
            max by (url) (
              (probe_success{job="services"} and on(instance) (up{job="services"} == 1))
              or on(url) (-2 * pi5_service_info{probed="true"})
              or on(url) (-1 * pi5_service_info{probed="false"})
            )
          '';
        }
      ];
      transformations = [
        {
          id = "organize";
          options = {
            excludeByName.Time = true;
            indexByName = {
              url = 0;
              Value = 1;
            };
            renameByName = {
              url = "Service";
              Value = "Availability";
            };
          };
        }
      ];
      fieldConfig.overrides = [
        {
          matcher = {
            id = "byName";
            options = "Service";
          };
          properties = [
            {
              id = "links";
              value = [
                {
                  title = "Open service";
                  url = "\${__value.raw}";
                  targetBlank = true;
                }
              ];
            }
          ];
        }
        {
          matcher = {
            id = "byName";
            options = "Availability";
          };
          properties = [
            {
              id = "mappings";
              value = [
                {
                  type = "value";
                  options = {
                    "-2".text = "Unknown";
                    "-1".text = "Unmonitored";
                    "0" = {
                      text = "Down";
                      color = "red";
                    };
                    "1" = {
                      text = "Up";
                      color = "green";
                    };
                  };
                }
              ];
            }
          ];
        }
      ];
      options.sortBy = [
        {
          displayName = "Service";
          desc = false;
        }
      ];
    }
    (graph 2 "CPU usage" "percent"
      ''100 * (1 - avg(rate(node_cpu_seconds_total{job="pi5",mode="idle"}[$__rate_interval])))''
      "CPU"
      0
      10
    )
    (graph 3 "Memory usage" "percent"
      ''100 * (1 - node_memory_MemAvailable_bytes{job="pi5"} / node_memory_MemTotal_bytes{job="pi5"})''
      "Memory"
      12
      10
    )
    (graph 4 "Temperatures" "celsius"
      # the Pi kernel exposes the CPU zone temperature twice through hwmon
      ''node_hwmon_temp_celsius{job="pi5",sensor!="temp0"} * on(instance, chip) group_left(chip_name) node_hwmon_chip_names{job="pi5"}''
      "{{chip_name}} / {{sensor}}"
      0
      18
    )
    (graph 5 "Fan speed" "rotrpm" ''node_hwmon_fan_rpm{job="pi5"}'' "Fan" 12 18)
  ];
}
