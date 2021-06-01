with import <nixpkgs> {};
let
  rev = "4f384662a85804fa2bc1bc1f99e70bb468e76f88";
  sops-nix = builtins.fetchTarball {
    url = "https://github.com/Mic92/sops-nix/archive/${rev}.tar.gz";
    sha256 = "1q600d0r02qpy05a4ppy0i8hrc0yx9r43hcfy87fj4riirrill6x";
  };
in
mkShell {
  sopsPGPKeyDirs = [
    "./keys/hosts"
    "./keys/users"
  ];
  nativeBuildInputs = [
    (pkgs.callPackage sops-nix {}).sops-pgp-hook
  ];
}
