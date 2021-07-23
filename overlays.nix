_: super:

{
  openvpn_aws = super.openvpn_24.overrideAttrs (oldAttrs: {
    patches = [
      (super.fetchpatch {
        url =
          "https://raw.githubusercontent.com/samm-git/aws-vpn-client/676908961b52bd8c4b8fc931077903d2d87f7362/openvpn-v2.4.9-aws.patch";
        sha256 = "0sykifdyqh6q2djxw1q7asac8kja67i9vsw14m3vh2d1825mm90l";
        name = "openvpn-v2.4.9-aws.patch";
      })
    ];
    nativeBuildInputs = oldAttrs.nativeBuildInputs
      ++ [ super.autoconf super.automake ];
  });

  # slack = super.slack.overrideAttrs (oldAttrs: {
  #   buildCommand = ''
  #     mkdir -pv $out/bin
  #     makeWrapper ${super.slack}/bin/slack $out/bin/slack --add-flags "--force-device-scale-factor=1.5"
  #   '';
  # });

  Firefox = super.callPackage ./overlays/firefox { };
}
