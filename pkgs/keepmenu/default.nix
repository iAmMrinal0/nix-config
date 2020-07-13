{ stdenv, python36Packages, fetchFromGitHub }:

let pyuserinput = python36Packages.buildPythonPackage rec {
      pname = "PyUserInput";
      version = "0.1.11";
      src = python36Packages.fetchPypi {
        inherit pname version;
        sha256 = "0azvlzfczrxhpxi15r37cbqkbbn5ip5y28bj5kmywh7pdk85wsq0";
      };

      doCheck = false;

      propagatedBuildInputs = [ python36Packages.xlib ];

      meta = {
        homepage = "https://github.com/PyUserInput/PyUserInput/";
        description = "A module for cross-platform control of the mouse and keyboard in python that is simple to use.";
      };
    };

    pykeepass = python36Packages.buildPythonPackage rec {
      pname = "pykeepass";
      version = "3.2.0";
      src = fetchFromGitHub {
        owner = "libkeepass";
        repo = pname;
        rev = "fd290bf5218e65c043eeba6860bc07434dc1119c";
        sha256 = "1wxbfpy7467mlnfsvmh685fhfnq4fki9y7yc9cylp30r5n3hisaj";
      };

      doCheck = false;
      propagatedBuildInputs = with python36Packages; [ lxml pycryptodome construct argon2_cffi python-dateutil future ];
    };

in python36Packages.buildPythonApplication rec {
  pname = "keepmenu";
  version = "0.6.1";

  src = fetchFromGitHub {
    owner = "firecat53";
    repo = pname;
    rev = "21b2fd29a4a36bbf8645e5570f3fa1e74453982a";
    sha256 = "0459nca0fkzchagl4zyazhiajgy1fkmyvyd127rzl2x5q2dlidca";
  };

  propagatedBuildInputs = [ pykeepass pyuserinput ];

  meta = with stdenv.lib; {
    description = "Fully featured Dmenu/Rofi frontend for managing Keepass databases.";
    homepage = "https://github.com/firecat53/keepmenu";
    license = licenses.gpl3;
  };
}
