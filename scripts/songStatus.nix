{ pkgs, polybar, ... }:

pkgs.writeShellScriptBin "getStatus" ''
    # The name of polybar bar which houses the main spotify module and the control modules.
    PARENT_BAR="bottom"
    PARENT_BAR_PID=$(${pkgs.procps}/bin/pgrep -a "polybar" | ${pkgs.gnugrep}/bin/grep "$PARENT_BAR" | ${pkgs.coreutils}/bin/cut -d" " -f1)

    # Set the source audio player here.
    # Players supporting the MPRIS spec are supported.
    # Examples: spotify, vlc, chrome, mpv and others.
    # Use `playerctld` to always detect the latest player.
    # See more here: https://github.com/altdesktop/playerctl/#selecting-players-to-control
    PLAYER="spotify"

    # Format of the information displayed
    # Eg. {{ artist }} - {{ album }} - {{ title }}
    # See more attributes here: https://github.com/altdesktop/playerctl/#printing-properties-and-metadata
    FORMAT="{{ title }} - {{ artist }}"

    # Sends $2 as message to all polybar PIDs that are part of $1
    update_hooks() {
        while IFS= read -r id
        do
            ${polybar}/bin/polybar-msg -p "$id" hook spotify-play-pause $2 1>/dev/null 2>&1
        done < <(echo "$1")
    }

    PLAYERCTL_STATUS=$(${pkgs.playerctl}/bin/playerctl --player=$PLAYER status 2>/dev/null)
    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        STATUS=$PLAYERCTL_STATUS
    else
        STATUS="No player is running"
    fi

    if [ "$1" == "--status" ]; then
        echo "$STATUS"
    else
        if [ "$STATUS" = "Stopped" ]; then
            echo "No music is playing"
        elif [ "$STATUS" = "Paused"  ]; then
            update_hooks "$PARENT_BAR_PID" 2
            ${pkgs.playerctl}/bin/playerctl --player=$PLAYER metadata --format "$FORMAT"
        elif [ "$STATUS" = "No player is running"  ]; then
            update_hooks "$PARENT_BAR_PID" 3
            echo "$STATUS"
        else
            update_hooks "$PARENT_BAR_PID" 1
            ${pkgs.playerctl}/bin/playerctl --player=$PLAYER metadata --format "$FORMAT"
        fi
    fi
  ''
