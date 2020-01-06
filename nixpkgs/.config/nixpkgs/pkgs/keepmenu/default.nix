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
        homepage = https://github.com/PyUserInput/PyUserInput/;
        description = "A module for cross-platform control of the mouse and keyboard in python that is simple to use.";
      };
    };

    pykeepass = python36Packages.buildPythonPackage rec {
      pname = "pykeepass";
      version = "3.1.2";
      src = fetchFromGitHub {
        owner = "libkeepass";
        repo = pname;
        rev = "253b66aab4ea9cceb3d11a60ad1ec4784fc31e2b";
        sha256 = "1d4xsaghxnp3zrnqvkfxgc4bgdriyl20y4raydmdivvqmygjh24f";
      };

      doCheck = false;
      propagatedBuildInputs = with python36Packages; [ lxml pycryptodome construct argon2_cffi python-dateutil future ];
    };

in python36Packages.buildPythonApplication rec {
  pname = "keepmenu";
  version = "0.5.9";

  src = fetchFromGitHub {
    owner = "firecat53";
    repo = pname;
    rev = "d7622ca2bcf7cc9c774e3d930508a7748337e8bb";
    sha256 = "1k92bnqhykg1avr1ny4fq0v22y4k53gy8bq4p8chsnqjv0p2mprq";
  };

  propagatedBuildInputs = [ pykeepass pyuserinput ];

  meta = with stdenv.lib; {
    description = "Fully featured Dmenu/Rofi frontend for managing Keepass databases.";
    homepage = https://github.com/firecat53/keepmenu;
    license = licenses.gpl3;
  };
}
