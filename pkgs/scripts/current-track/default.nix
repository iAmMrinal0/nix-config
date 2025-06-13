{ lib, stdenv, writeShellScriptBin, playerctl }:

writeShellScriptBin "current-track" ''
  PLAYER=spotify
  ARGS="--player=$PLAYER"

  getTrack() {
      format=$(${playerctl}/bin/playerctl $ARGS metadata --format='{{status}}')
      if [ "$format" = "Playing" ]
      then
         echo "" $(${playerctl}/bin/playerctl $ARGS  metadata --format='{{title}} - {{artist}}')
      elif [ "$format" = "Paused" ]
      then
         echo "" $(${playerctl}/bin/playerctl $ARGS  metadata --format='{{title}} - {{artist}}')
      elif [ "$format" = "No players found" ]
      then
         echo ""
      else
         echo ""
      fi
  }

  case $BLOCK_BUTTON in
      3) ${playerctl}/bin/playerctl play-pause $ARGS ;; # right click, pause/unpause
      4) ${playerctl}/bin/playerctl prev       $ARGS ;; # scroll up, previous
      5) ${playerctl}/bin/playerctl next       $ARGS ;; # scroll down, next
      *) getTrack ;;
  esac
''
