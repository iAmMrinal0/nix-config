self: super:

{
  rescuetime = super.rescuetime.overrideAttrs (oldAttrs: {
    version = "2.14.3.1"; # Latest version which has a different sha as compared to official nixpkgs
    src = super.fetchurl {
      url = "https://www.rescuetime.com/installers/rescuetime_current_amd64.deb";
      sha256 = "03bky9vja7fijz45n44b6gawd6q8yd30nx6nya9lqdlxd1bkqmji";
      };
  });
}
