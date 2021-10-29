{ lib, python3Packages, fetchFromGitHub }:

python3Packages.buildPythonApplication rec {
  pname = "keepmenu";
  version = "unstable-2021-10-26";

  src = fetchFromGitHub {
    owner = "firecat53";
    repo = "keepmenu";
    rev = "dcfe85e8cce862e996203ea572430eef225a5a40";
    sha256 = "JTupb3kr6H52a+MqOTcRVHZyQXPX9KbBfIvakrnctl0=";
  };

  doCheck = false;
  propagatedBuildInputs =
    [ python3Packages.pykeepass python3Packages.pynput ];

  meta = with lib; {
    description =
      "Fully featured Dmenu/Rofi frontend for managing Keepass databases.";
    homepage = "https://github.com/firecat53/keepmenu";
    license = licenses.gpl3;
  };
}
