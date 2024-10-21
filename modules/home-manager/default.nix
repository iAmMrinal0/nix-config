inputs@{ pkgs, ... }:

{
  imports = [
    ./autorandr.nix
    ./dunstrc.nix
    ./chromium.nix
    ./feh.nix
    ./rofi.nix
    ./git.nix
    ./tmux.nix
    ./picom.nix
    ./zathura.nix
    ./kitty.nix
    ./htop.nix
    ./firefox.nix
    ./gtk.nix
    ./systemd.nix
    ./xsession.nix
    ./qt.nix
    (import ./zsh {
      inherit pkgs;
      inherit (inputs)
        zsh-autosuggestions zsh-you-should-use zsh-history-substring-search
        zsh-nix-shell;
    })
  ];
}
