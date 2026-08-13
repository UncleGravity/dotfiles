{node, ...}: let
  kiwiAddress = "192.168.1.200";
  nodeExporterPort = 9100;
  gpuExporterPort = 9835;
in {
  services.prometheus.exporters = {
    node = {
      enable = true;
      listenAddress = node.managementAddress;
      port = nodeExporterPort;
      enabledCollectors = [
        "ethtool"
        "processes"
        "systemd"
      ];
      extraFlags = [
        "--no-collector.cpufreq"
        "--collector.ethtool.device-include=^(fabric0|fabric1)$"
        "--collector.ethtool.metrics-include=^((rx|tx)_bytes_phy|(rx|tx)_.*(buffer|cong|discard|drop|ecn|error|marked|pause).*)$"
        "--collector.infiniband.device-include=^mlx5_(0|2)$"
      ];
    };

    nvidia-gpu = {
      enable = true;
      listenAddress = node.managementAddress;
      port = gpuExporterPort;
      extraFlags = [
        "--query-field-names=uuid,name,driver_version,temperature.gpu,utilization.gpu,utilization.memory,power.draw,clocks.current.graphics,clocks.current.sm,pstate"
      ];
    };
  };

  networking.firewall.extraCommands = ''
    iptables -A nixos-fw -i mgmt0 -s ${kiwiAddress}/32 -p tcp -m multiport --dports ${toString nodeExporterPort},${toString gpuExporterPort} -j nixos-fw-accept
  '';

  systemd.services = {
    prometheus-node-exporter = {
      after = ["network-online.target"];
      wants = ["network-online.target"];
    };
    prometheus-nvidia-gpu-exporter = {
      after = ["network-online.target"];
      wants = ["network-online.target"];
    };
  };
}
