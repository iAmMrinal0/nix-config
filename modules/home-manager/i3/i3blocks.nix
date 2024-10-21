{ pkgs, ... }:

let
  currentTrack = import ../../../scripts/currentTrack.nix { inherit pkgs; };
  dunstNotifToggle = import ../../../scripts/i3DunstToggle.nix { inherit pkgs; };
  bluetooth_battery = import ../../../scripts/bluetooth_battery.nix { inherit pkgs; };
  # using this fork because few scripts have hardcoded shebangs
  # and the user has a patch PR open in the source repo
  i3blocks-contrib = pkgs.fetchFromGitHub {
    owner = "CreativeCactus";
    repo = "i3blocks-contrib";
    rev = "b7871d7809b0bcd0ce1c574e4d967d546ebe2f8a";
    sha256 = "070vpf3nfw4b4cblacr0c5xfs3h6asbbzclcj911skyli3wjrmid";
  };
in pkgs.writeTextFile {
  name = "i3blocksconfig";
  text = ''
    # i3blocks config file
    #
    # Please see man i3blocks for a complete reference!
    # The man page is also hosted at http://vivien.github.io/i3blocks
    #
    # List of valid properties:
    #
    # align
    # color
    # command
    # full_text
    # instance
    # interval
    # label
    # min_width
    # name
    # separator
    # separator_block_width
    # short_text
    # signal
    # urgent

    # Global properties
    command=${i3blocks-contrib}/$BLOCK_NAME/$BLOCK_NAME
    separator_block_width=25
    markup=pango

    [song]
    command=${currentTrack}
    # label=
    interval=1
    color=#87AFAF

    [volume]
    label= 
    instance=Master
    #instance=PCM
    interval=1
    signal=10
    color=#FFAF00

    [iface]
    color=#87AF87
    interval=10

    [wifi]
    command=echo " $(${pkgs.wirelesstools}/bin/iwgetid -r)"
    color=#00FF00
    interval=10

    #[cpu_usage]
    #label=
    #interval=10
    #min_width= 100.00%
    #separator=false

    [load_average]
    label= 
    interval=1

    [battery]
    label=⚡
    interval=15

    [bluetooth]
    command=${bluetooth_battery}
    interval=30

    [dunst]
    command=${dunstNotifToggle}
    interval=1
  '';
}
