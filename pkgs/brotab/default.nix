{ stdenv, python3, fetchFromGitHub }:

python3.pkgs.buildPythonApplication rec {
  pname = "brotab";
  version = "1.1.0";

  src = fetchFromGitHub {
    owner = "balta2ar";
    repo = "brotab";
    rev = version;
    sha256 = "17yj5i8p28a7zmixdfa1i4gfc7c2fmdkxlymazasar58dz8m68mw";
  };

  propagatedBuildInputs = [ python3.pkgs.requests python3.pkgs.psutil python3.pkgs.flask python3.pkgs.setuptools ];
  checkInputs = [ python3.pkgs.pytest ];

  meta = with stdenv.lib; {
    description = "Control your browser's tabs from the command line";
    homepage = "https://github.com/balta2ar/brotab";
    license = licenses.mit;
  };
}
