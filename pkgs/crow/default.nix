{ stdenv, lib, fetchFromGitHub, cmake, asio, }:

stdenv.mkDerivation (finalAttrs: {
  pname = "crow";
  version = "1.2.0";

  src = fetchFromGitHub {
    owner = "CrowCpp";
    repo = "Crow";
    rev = "v${finalAttrs.version}";
    sha256 = "sha256-fokj+KiS6frPVOoOvETxW3ue95kCcYhdhOlN3efzBd4=";
  };

  nativeBuildInputs = [ cmake ];

  buildInputs = [ asio ];

  meta = {
    description = "A Fast and Easy to use microframework for the web";
    homepage = "https://crowcpp.org";
    license =
      lib.flatten (builtins.attrValues { inherit (lib.licenses) bsd3; });
    platforms =
      lib.flatten (builtins.attrValues { inherit (lib.platforms) linux; });
    maintainers = [ ];
  };
})
