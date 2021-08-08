{ lib, python37Packages, fetchFromGitHub }:

python37Packages.buildPythonApplication rec {
  pname = "keepmenu";
  version = "unstable-2021-04-21";

  src = fetchFromGitHub {
    owner = "firecat53";
    repo = pname;
    rev = "354c0944e4a0bc11f0ebb1ecfe9289d1f35d353b";
    sha256 = "sha256-xVwLt2TLM2Hgpxl4QyCvCgEUoLinzp4eibRORtqRHLs=";
  };

  propagatedBuildInputs =
    [ python37Packages.pykeepass python37Packages.pynput ];

  meta = with lib; {
    description =
      "Fully featured Dmenu/Rofi frontend for managing Keepass databases.";
    homepage = "https://github.com/firecat53/keepmenu";
    license = licenses.gpl3;
  };
}
