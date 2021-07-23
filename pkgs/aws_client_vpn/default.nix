{ config, lib, pkgs, ... }:
let
  VPN_HOST =
    "cvpn-endpoint-010604241ce5b8f84.prod.clientvpn.ap-south-1.amazonaws.com";
  goScript = "${
      pkgs.fetchFromGitHub {
        owner = "samm-git";
        repo = "aws-vpn-client";
        rev = "263479f5fc0fde860e5b463bbc15ab3806f861c9";
        sha256 = "10agwhs59mjcjsmfnvj0gzmc5yz42br39gdjdk0b3xwr0dncgf34";
      }
    }/server.go";
  OVPN_CONF = import ./vpn.nix { inherit config pkgs; };
  PORT = "1194";
  PROTO = "udp";
in pkgs.writeShellScriptBin "aws_client_vpn_connect" ''
  set -x
  set -e

  $(${pkgs.go}/bin/go run ${goScript}) &

  wait_file() {
    local file="$1"; shift
    local wait_seconds="''${1:-10}"; shift # 10 seconds as default timeout
    until test $((wait_seconds--)) -eq 0 -o -f "$file" ; do sleep 1; done
    ((++wait_seconds))
  }

  # create random hostname prefix for the vpn gw
  RAND=$(${pkgs.openssl}/bin/openssl rand -hex 12)

  # resolv manually hostname to IP, as we have to keep persistent ip address
  SRV=$(${pkgs.dnsutils}/bin/dig a +short "$RAND.${VPN_HOST}"|head -n1)
  rm -f /tmp/saml-response.txt

  echo "Getting SAML redirect URL from the AUTH_FAILED response (host: $SRV:${PORT})"
  OVPN_OUT=$(${pkgs.openvpn_aws}/bin/openvpn --config ${OVPN_CONF} --verb 3 \
       --proto ${PROTO} --remote "$SRV" ${PORT} \
       --auth-user-pass <( printf "%s\n%s\n" "N/A" "ACS::35001" ) \
      2>&1 | grep AUTH_FAILED,CRV1)

  echo "Opening browser and wait for the response file..."
  URL=$(echo "$OVPN_OUT" | grep -Eo 'https://.+')
  echo "$URL"
  ${pkgs.xdg_utils}/bin/xdg-open "$URL"

  # Focus on urgent tab and click through the account selection and close the tab
  ${pkgs.xdotool}/bin/xdotool key "Super_L+Shift+x" sleep 5 key "f" sleep 2 key "d" sleep 5 key "x"

  wait_file "/tmp/saml-response.txt" 30 || {
    echo "SAML Authentication time out"
    exit 1
  }

  # get SID from the reply
  VPN_SID=$(echo "$OVPN_OUT" | awk -F : '{print $7}')

  printf "%s\n%s\n" "N/A" "CRV1::''${VPN_SID}::$(cat /tmp/saml-response.txt)" > /tmp/creds

  # Finally OpenVPN with a SAML response we got
  # Delete saml-response.txt after connect
  sudo ${pkgs.openvpn_aws}/bin/openvpn --config "${OVPN_CONF}" \
      --verb 3 --auth-nocache --inactive 3600 \
      --proto ${PROTO} --remote $SRV ${PORT} \
      --script-security 2 \
      --auth-user-pass /tmp/creds
  rm /tmp/creds
  ${pkgs.procps}/bin/pkill -P $$
''
