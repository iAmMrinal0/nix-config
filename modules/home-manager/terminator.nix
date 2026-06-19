{ config, ... }:

let
  font = config.personal.theming.font;
in {
  xdg.configFile."terminator/config".text = ''
    [global_config]
      title_use_system_font = False
      title_font = ${font.regular} ${toString font.size}
    [profiles]
      [[default]]
        use_system_font = False
        font = ${font.regular} ${toString font.size}
        scrollback_infinite = True
        cursor_shape = ibeam
        copy_on_selection = True
        show_titlebar = False
  '';
}
