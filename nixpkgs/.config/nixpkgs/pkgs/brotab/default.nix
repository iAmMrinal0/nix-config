{ stdenv, python3, fetchFromGitHub }:

with python3.pkgs;

buildPythonApplication rec {
  pname = "brotab";
  version = "2018-10-25";

  src = fetchFromGitHub {
    owner = "balta2ar";
    repo = "brotab";
    rev = "6f95713ffb8296e3317187af2e7f802bf46c3178";
    sha256 = "1z11x28q1ab3vhfif437h5r41qp88xmk1v1cbvgd4sg8na10sgcx";
  };

  propagatedBuildInputs = [ requests psutil flask ipython ];
  checkInputs = [ pytest ];

  meta = with stdenv.lib; {
    description = "Control your browser's tabs from the command line";
    homepage = https://github.com/balta2ar/brotab;
    license = licenses.mit;
  };
}
