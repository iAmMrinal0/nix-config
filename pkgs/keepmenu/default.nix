{ lib, python36Packages, fetchFromGitHub }:

python36Packages.buildPythonApplication rec {
  pname = "keepmenu";
  version = "0.6.2";

  src = fetchFromGitHub {
    owner = "firecat53";
    repo = pname;
    rev = "81a847b8230a0102653ea445d7c87f6ddf44b04a";
    sha256 = "150xjdyb1qzkvhsv8zx7ddvllx918m0gpjaxydckqlji91yimfz3";
  };

  propagatedBuildInputs = [ python36Packages.pykeepass python36Packages.pynput ];

  meta = with lib; {
    description = "Fully featured Dmenu/Rofi frontend for managing Keepass databases.";
    homepage = "https://github.com/firecat53/keepmenu";
    license = licenses.gpl3;
  };
}
