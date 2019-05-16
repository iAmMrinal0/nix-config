# NixOS Config

This repository holds my configuration for NixOS v19.03, for the desktop I use at Juspay and user config, which is managed by [home-manager](https://github.com/rycee/home-manager/)

## Usage

I use stow to manage these. Assuming you are in the project directory:

- Run `stow nixpkgs` which will create a symlink in the `~/.config/nixpkgs` folder.
- If you are starting from a fresh installation of `home-manager`, you mostly probably have the `home.nix` file it creates in `~/.config/nixpkgs/home.nix`. If you wish to use this repository, you can go ahead and remove that file and run the command again.

Any feedback and suggestions are welcome. :)

<b>PS:</b> If you are interested in dotfiles, maybe my [dotfiles repo](https://github.com/iammrinal0/dotfiles) is worth a look.
