{ ... }: {
  programs.htop = {
    enable = true;
    settings = {
      sortKey = 46;
      left_meters = [ "LeftCPUs" "Memory" "Swap" ];
      left_meter_modes = [ 1 1 1 ];
      right_meters = [ "RightCPUs" "Tasks" "LoadAverage" "Uptime" ];
      right_meter_modes = [ 1 2 2 2 ];
      cpu_count_from_one = 1;
      show_cpu_usage = true;
      enable_mouse = true;
      delay = 15;
    };
  };
}
