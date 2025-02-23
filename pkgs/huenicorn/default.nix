{ stdenv, lib, fetchFromGitLab, cmake, pkg-config, curl, opencv, asio
, nlohmann_json, mbedtls, glm, pipewire, glib, pcre2, libsepol, libselinux, xorg
, clang, util-linuxMinimal, makeWrapper, crow }:

let 
  version = "1.0.10";
  in
    stdenv.mkDerivation {
  pname = "huenicorn";

  src = fetchFromGitLab {
    owner = "openjowelsofts";
    repo = "huenicorn";
    rev = "v${version}";
    sha256 = "sha256-d1M0JJLadHzOVK31Tz6fUTcGR2/0xVp2czoLynghcUM=";
  };

  nativeBuildInputs = [ makeWrapper cmake pkg-config clang ];

  buildInputs = [
    curl
    opencv
    asio
    nlohmann_json
    mbedtls
    glm
    pipewire
    glib
    pcre2
    libsepol
    libselinux
    xorg.libX11
    xorg.libXext
    xorg.libXrandr
    util-linuxMinimal
    crow
  ];

  env.NIX_CFLAGS_COMPILE = "-Wno-error -Wmismatched-tags";

  cmakeFlags = [
    "-DCMAKE_BUILD_TYPE=MinSizeRel"
    "-DCMAKE_C_COMPILER=clang"
    "-DCMAKE_CXX_COMPILER=clang++"
  ];

  preInstall = ''
    mkdir -p $out/share/huenicorn
    mkdir -p $out/bin
  '';

  installPhase = ''
    runHook preInstall

    mv $PWD/webroot $out/share/huenicorn
    mv $PWD/huenicorn $out/bin

    wrapProgram $out/bin/huenicorn --chdir $out/share/huenicorn

    runHook postInstall
  '';

  meta = {
    description =
      "Huenicorn is a free Philips Hue™ bias lighting driver for Gnu/Linux";
    homepage = "https://huenicorn.org";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
    maintainers = [ ];
  };
  name = "huenicorn";
}
