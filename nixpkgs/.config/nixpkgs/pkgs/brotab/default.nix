{ stdenv, python3, fetchFromGitHub }:

with python3.pkgs;

buildPythonApplication rec {
  pname = "brotab";
  version = "2018-10-25";

  src = fetchFromGitHub {
    owner = "balta2ar";
    repo = "brotab";
    rev = "6f95713ffb8296e3317187af2e7f802bf46c3178";
    sha256 = "014slk92687f226vkgsr9pl5x7gs7y6ljbid90dw3p5kw014dqxy";
  };

  propagatedBuildInputs = [ requests psutil flask ipython ];
  checkInputs = [ pytest ];

  meta = with stdenv.lib; {
    description = "Control your browser's tabs from the command line";
    homepage = https://github.com/balta2ar/brotab;
    license = licenses.mit;
  };
}
