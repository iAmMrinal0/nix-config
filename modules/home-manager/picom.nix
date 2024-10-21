{ ... }:

{
  services.picom = {
    enable = true;
    # vSync = "opengl-swc";
    shadowOpacity = 0.5;
    shadow = true;
    shadowOffsets = [ (-5) (-5) ];
    # package = pkgs.nur.repos.reedrw.picom-next-ibhagwan;
    fade = true;
    fadeSteps = [ 3.0e-2 3.0e-2 ];
    fadeDelta = 4;
    # blur = true;
    # blurExclude = [ "window_type = 'dock'" "window_type = 'desktop'" ];
    shadowExclude = [
      "! name~=''"
      "name = 'Notification'"
      "name = 'Plank'"
      "name = 'Docky'"
      "name = 'Kupfer'"
      "name = 'xfce4-notifyd'"
      "name *= 'VLC'"
      "name *= 'picom'"
      "name *= 'Chromium'"
      "name *= 'Chrome'"
      "name *= 'Firefox'"
      "class_g = 'Conky'"
      "class_g = 'Kupfer'"
      "class_g = 'Synapse'"
      "class_g ?= 'Notify-osd'"
      "class_g ?= 'Cairo-dock'"
      "class_g ?= 'Xfce4-notifyd'"
      "class_g ?= 'Xfce4-power-manager'"
    ];
    # extraOptions = ''
    #   glx-no-stencil = true;

    #   glx-copy-from-front = false;

    #   shadow-radius = 5;

    #   shadow-ignore-shaped = false;

    #   frame-opacity = 1;
    #   inactive-opacity-override = false;

    #   # blur-method = "dual_kawase";
    #   blur-strength = 8;
    #   blur-background-frame = false;
    #   blur-background-fixed = false;

    #   mark-wmwin-focused = true;
    #   mark-ovredir-focused = true;
    #   use-ewmh-active-win = true;
    #   detect-rounded-corners = true;
    #   detect-client-opacity = true;

    #   dbe = false;
    #   sw-opti = false;

    #   unredir-if-possible = true;

    #   focus-exclude = [ ];

    #   detect-transient = true;
    #   detect-client-leader = true;

    #   corner-radius = 25;
    #   rounded-corners-exclude = [
    #       "window_type = 'dock'",
    #       "_NET_WM_STATE@:32a *= '_NET_WM_STATE_FULLSCREEN'",
    #       "class_g = 'Polybar'",
    #   ];
    #   round-borders = 1;

    #   # wintypes:
    #   # {
    #   #     tooltip =
    #   #     {
    #   #         # fade: Fade the particular type of windows.
    #   #         fade = true;
    #   #         # shadow: Give those windows shadow
    #   #         shadow = false;
    #   #         # opacity: Default opacity for the type of windows.
    #   #         opacity = 0.85;
    #   #         # focus: Whether to always consider windows of this type focused.
    #   #         focus = true;
    #   #     };
    #   # };
    # '';
  };
}
