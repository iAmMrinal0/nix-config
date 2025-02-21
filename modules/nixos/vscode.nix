{ lib, config, inputs, pkgs, ... }:

let
  vscodeExtensions = (with pkgs.vscode-extensions; [ github.copilot-chat ])
    ++ (with pkgs.vscode-marketplace;
      [
        ms-vscode-remote.vscode-remote-extensionpack
        ms-vscode.remote-explorer
        ms-vsliveshare.vsliveshare
        ms-python.vscode-pylance
        ms-python.python
        github.copilot
        pkief.material-icon-theme
        ms-vscode-remote.remote-containers
        github.vscode-pull-request-github
      ] ++ (with pkgs.open-vsx; [
        mechatroner.rainbow-csv
        ahmadalli.vscode-nginx-conf
        bbenoist.nix
        berberman.vscode-cabal-fmt
        bierner.markdown-mermaid
        bigmoon.language-yesod
        davidanson.vscode-markdownlint
        dhall.dhall-lang
        dhall.vscode-dhall-lsp-server
        dksedgwick.xstviz
        eamodio.gitlens
        editorconfig.editorconfig
        hashicorp.terraform
        haskell.haskell
        jdinhlife.gruvbox
        jnoortheen.nix-ide
        jock.svg
        joeandaverde.sqitch-plan
        justusadam.language-haskell
        miguelsolorio.fluent-icons
        mkhl.direnv
        william-voyek.vscode-nginx
        ms-azuretools.vscode-docker
        ms-python.black-formatter
        ms-vscode-remote.remote-ssh
        ms-vsliveshare.vsliveshare
        raynigon.nginx-formatter
        redhat.vscode-yaml
        statelyai.stately-vscode
        # vscodeemacs.emacs
        lfs.vscode-emacs-friendly
        graphql.vscode-graphql-syntax
        tootone.org-mode
        tailscale.vscode-tailscale
      ]));

  vscode-with-extensions = pkgs.vscode-with-extensions.override {
    vscodeExtensions = vscodeExtensions ++ [
      ((pkgs.vscode-utils.buildVscodeExtension {
        name = "haskell-yesod-quasiquotes-0.1.2";
        src = inputs.haskell-yesod-quasiquotes;
        version = "0.1.2";
        vscodeExtName = "haskell-yesod-quasiquotes";
        vscodeExtPublisher = "mel-brown";
        vscodeExtUniqueId = "mel-brown.haskell-yesod-quasiquotes";
      }).overrideAttrs (_: { sourceRoot = null; }))
    ];
  };
in { environment.systemPackages = [ vscode-with-extensions ]; }
