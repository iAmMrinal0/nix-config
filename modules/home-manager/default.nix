inputs@{ pkgs, ... }:

{
  imports = [
    ./autorandr.nix
    ./blueman-applet.nix
    ./chromium.nix
    ./dunstrc.nix
    ./feh.nix
    ./firefox.nix
    ./git.nix
    ./gtk.nix
    ./htop.nix
    ./kitty.nix
    ./picom.nix
    ./qt.nix
    ./rofi.nix
    ./systemd.nix
    ./tmux.nix
    ./xsession.nix
    ./zathura.nix
    (import ./zsh {
      inherit pkgs;
      inherit (inputs)
        zsh-autosuggestions zsh-you-should-use zsh-history-substring-search
        zsh-nix-shell;
    })
  ];
}
