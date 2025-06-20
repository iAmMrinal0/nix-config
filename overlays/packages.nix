self: super: {
  scripts = import ../pkgs/scripts { pkgs = super; };

  crow = super.callPackage ../pkgs/crow { };
  huenicorn = super.callPackage ../pkgs/huenicorn { inherit (self) crow; };
}
