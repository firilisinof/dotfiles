let
  datasource = {
    type = "prometheus";
    uid = "prometheus";
  };
  cpu = ''100 * (1 - avg(rate(node_cpu_seconds_total{job="pi5",mode="idle"}[$__rate_interval])))'';
  memory = ''100 * (1 - node_memory_MemAvailable_bytes{job="pi5"} / node_memory_MemTotal_bytes{job="pi5"})'';
  fan = ''node_hwmon_fan_rpm{job="pi5"}'';
  temperatures = ''node_hwmon_temp_celsius{job="pi5",sensor!="temp0"} * on(instance, chip) group_left(chip_name) node_hwmon_chip_names{job="pi5"}'';
  cpuTemp = ''node_hwmon_temp_celsius{job="pi5",sensor="temp1"} and on(instance, chip) node_hwmon_chip_names{job="pi5",chip_name="cpu_thermal"}'';

  # keep failed probes distinct from failed scrapes and shortcuts without probes
  availability = ''
    (probe_success{job="services"} and on(instance) (up{job="services"} == 1))
    or on(url) (-2 * pi5_service_info{probed="true"})
  '';
  states = {
    "-2" = {
      text = "Unknown";
      color = "gray";
    };
    "0" = {
      text = "Down";
      color = "red";
    };
    "1" = {
      text = "Up";
      color = "green";
    };
  };
  valueMappings = options: [
    {
      type = "value";
      inherit options;
    }
  ];
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
  stat = id: title: unit: decimals: expr: x: w: {
    inherit id title datasource;
    type = "stat";
    gridPos = {
      inherit x w;
      y = 0;
      h = 4;
    };
    fieldConfig.defaults = { inherit unit decimals; };
    options = {
      textMode = "value";
      colorMode = "none";
      graphMode = "none";
    };
    targets = [
      {
        inherit expr;
        refId = "A";
        instant = true;
        range = false;
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
    (stat 6 "CPU" "percent" 1 cpu 0 5)
    (stat 7 "Memory" "percent" 1 memory 5 5)
    (stat 8 "CPU temperature" "celsius" 1 cpuTemp 10 5)
    (stat 9 "Fan" "rotrpm" 0 fan 15 4)
    (stat 10 "Last successful backup" "dateTimeFromNow" 0
      ''pi5_backup_last_success_timestamp_seconds{job="pi5"} * 1000''
      19
      5
    )
    {
      id = 1;
      title = "Services";
      type = "table";
      inherit datasource;
      gridPos = {
        x = 0;
        y = 4;
        w = 10;
        h = 12;
      };
      targets = [
        {
          refId = "A";
          instant = true;
          range = false;
          format = "table";
          expr = ''
            max by (url) (${availability} or on(url) (-1 * pi5_service_info{probed="false"}))
              * on(url) group_left(service, sort_key) max by (url, service, sort_key) (pi5_service_info)
          '';
        }
      ];
      transformations = [
        {
          id = "sortBy";
          options.sort = [ { field = "sort_key"; } ];
        }
        {
          id = "organize";
          options = {
            excludeByName = {
              Time = true;
              sort_key = true;
            };
            indexByName = {
              service = 0;
              Value = 1;
              url = 2;
            };
            renameByName = {
              service = "Service";
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
                  url = "\${__data.fields.url}";
                  targetBlank = true;
                }
              ];
            }
          ];
        }
        {
          matcher = {
            id = "byName";
            options = "url";
          };
          properties = [
            {
              id = "custom.hidden";
              value = true;
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
              value = valueMappings (states // { "-1".text = "Unmonitored"; });
            }
            {
              id = "custom.cellOptions";
              value.type = "color-text";
            }
          ];
        }
      ];
      options.cellHeight = "sm";
    }
    {
      id = 11;
      title = "Service availability";
      type = "state-timeline";
      inherit datasource;
      gridPos = {
        x = 10;
        y = 4;
        w = 14;
        h = 12;
      };
      timeFrom = "24h";
      maxDataPoints = 1441;
      targets = [
        {
          refId = "A";
          # use the current names for samples collected before the launcher was added
          expr = ''
            max by (url) (${availability})
              * on(url) group_left(service) max by (url, service) (pi5_service_info{probed="true"} @ end())
          '';
          legendFormat = "{{service}}";
          range = true;
        }
      ];
      fieldConfig.defaults = {
        mappings = valueMappings states;
        custom = {
          spanNulls = false;
          insertNulls = 120000;
          fillOpacity = 85;
          lineWidth = 0;
        };
      };
      options = {
        mergeValues = true;
        showValue = "never";
        rowHeight = 0.8;
        legend.showLegend = false;
      };
    }
    (graph 2 "CPU usage" "percent" cpu "CPU" 0 16)
    (graph 3 "Memory usage" "percent" memory "Memory" 12 16)
    (graph 4 "Temperatures" "celsius" temperatures "{{chip_name}} / {{sensor}}" 0 24)
    (graph 5 "Fan speed" "rotrpm" fan "Fan" 12 24)
  ];
}
