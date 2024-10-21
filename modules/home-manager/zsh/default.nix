inputs@{ pkgs, ... }:

{
  imports = [
    (import ./zsh.nix {
      inherit pkgs;
      inherit (inputs)
        zsh-autosuggestions zsh-you-should-use zsh-history-substring-search
        zsh-nix-shell;
    })
  ];
}
