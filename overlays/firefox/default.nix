{ stdenv, fetchurl, lib, undmg, unzip }:
let version = "90.0";

in stdenv.mkDerivation rec {
  inherit version;

  name = "Firefox-${version}";
  buildInputs = [ undmg unzip ];
  sourceRoot = ".";
  phases = [ "unpackPhase" "installPhase" ];
  installPhase = ''
    mkdir -p "$out/Applications"
    cp -r Firefox.app "$out/Applications/Firefox.app"
  '';

  src = fetchurl {
    name = "Firefox-${version}.dmg";
    url =
      "https://download-installer.cdn.mozilla.net/pub/firefox/releases/${version}/mac/en-US/Firefox%20${version}.dmg";
    sha256 = "0qw8biv5p7j1gqz0ziadj7hd0kh86nlndwxvc39ifq52w8w81h6v";
  };

  meta = with lib; {
    description = "The Firefox web browser";
    homepage = "https://www.mozilla.org/en-GB/firefox";
    maintainers = with maintainers; [ cmacrae ];
    platforms = platforms.darwin;
  };
}
