{ stdenv, python3, fetchFromGitHub }:

with python3.pkgs;

let pyuserinput = buildPythonPackage rec {
  pname = "PyUserInput";
  version = "0.1.11";
  src = fetchPypi {
    inherit pname version;
    sha256 = "0azvlzfczrxhpxi15r37cbqkbbn5ip5y28bj5kmywh7pdk85wsq0";
  };

  doCheck = false;

  propagatedBuildInputs = [ xlib ];

  meta = {
    homepage = https://github.com/PyUserInput/PyUserInput/;
    description = "A module for cross-platform control of the mouse and keyboard in python that is simple to use.";
  };
};

in

buildPythonApplication rec {
  pname = "keepmenu";
  version = "0.5.7";

  src = fetchFromGitHub {
    owner = "firecat53";
    repo = pname;
    rev = version;
    sha256 = "1by4536s4h81d2snrkpbl1fx70lyvadx0ia44sswrnsfiyxiahkr";
  };

  propagatedBuildInputs = [ pykeepass pyuserinput ];

  meta = with stdenv.lib; {
    description = "Fully featured Dmenu/Rofi frontend for managing Keepass databases.";
    homepage = https://github.com/firecat53/keepmenu;
    license = licenses.gpl3;
  };
}
