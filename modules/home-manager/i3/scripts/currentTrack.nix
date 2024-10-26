{ pkgs, ... }:

pkgs.writeShellScript "currentTrack" ''

  PLAYER=spotify
  ARGS="--player=$PLAYER"

  getTrack() {
      format=$(${pkgs.playerctl}/bin/playerctl $ARGS metadata --format='{{status}}')
      if [ "$format" = "Playing" ]
      then
         echo "" $(${pkgs.playerctl}/bin/playerctl $ARGS  metadata --format='{{title}} - {{artist}}')
      elif [ "$format" = "Paused" ]
      then
         echo "" $(${pkgs.playerctl}/bin/playerctl $ARGS  metadata --format='{{title}} - {{artist}}')
      elif [ "$format" = "No players found" ]
      then
         echo ""
      else
         echo ""
      fi
  }

  case $BLOCK_BUTTON in
      3) ${pkgs.playerctl}/bin/playerctl play-pause $ARGS ;; # right click, pause/unpause
      4) ${pkgs.playerctl}/bin/playerctl prev       $ARGS ;; # scroll up, previous
      5) ${pkgs.playerctl}/bin/playerctl next       $ARGS ;; # scroll down, next
      *) getTrack ;;
  esac
''
