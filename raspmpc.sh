#!/bin/bash

# Default settings
export MPD_HOST=localhost #password@host
export MPD_PORT=6600      # Default MPD port is 6600
NOTIFY_COMMAND=espeak

# Load config file
CONFIG_FILE=~/.raspmpcrc
if [ -f ${CONFIG_FILE} ]; then
	source ${CONFIG_FILE}
fi


# Search database and notify on error/no match
function mpc_search {
	MATCHES=$(mpc_cmd search "$1" "${@:2}")
	MPC_EXIT_CODE=$?

	if [ $MPC_EXIT_CODE -eq 0 ]; then
		if [ "${MATCHES}" == "" ]; then
			notify "No matches found"
			return 1
		else
			echo "${MATCHES}"
		fi
	fi

	return ${MPC_EXIT_CODE}
}

# Add music to playlist
function mpc_add {
	MATCHES=$(mpc_search $@)
	if [ $? -eq 0 ]; then
		echo "${MATCHES}"|mpc_cmd add && mpc_cmd play
	fi

	return $MPC_EXIT_CODE
}

# Replace music in playlist
function mpc_replace {
	MATCHES=$(mpc_search $@)
	if [ $? -eq 0 ]; then
		mpc_cmd clear && echo "${MATCHES}"|mpc_cmd add && mpc_cmd play
	fi
}

# Add playlist to playlist
function mpc_add_playlist {
	PLAYLISTS=$(mpc_cmd lsplaylists)

	if [ $? -eq 0 ]; then
		MATCHES=$(echo $PLAYLISTS|grep --ignore-case "$@")
		if [ "${MATCHES}" == "" ]; then
			notify "No matches found"
		else
			echo "${MATCHES}"|mpc_cmd load && mpc_cmd play
		fi
	fi
}

# Run mpc and handle error messages
function mpc_cmd {
	ERR_TMP=$(mktemp)
	MPC_OUTPUT=$(mpc -q $@ 2>$ERR_TMP)
	MPC_EXIT_CODE=$?
	if [ ${MPC_EXIT_CODE} -ne 0 ]; then
		notify "$(cat $ERR_TMP)"
	fi
	rm $ERR_TMP
	echo -n "${MPC_OUTPUT}"
	return ${MPC_EXIT_CODE}
}

# Send notification to user
function notify {
	command -v "${NOTIFY_COMMAND}" > /dev/null
	if [ $? -eq 0 ]; then
		${NOTIFY_COMMAND} "$@"
	fi
}

notify "RaspMPC started."

# Fetch current MPD status to verify connection
mpc_cmd

while true;
do
	echo ""
	echo "n Play next song"
	echo "p Play previous song"
	echo "  Toggle play/pause"
	echo "+ Increase volume"
	echo "- Decrease volume"
	echo "c Clear playlist"
	echo "d Delete currently playing song"
	echo "/ Search and add matches"
	echo "\\ Clear, search and add matches"
	echo "a Search and add artists"
	echo "A Search and add albums"
	echo "s Search and add songs"
	echo "u Update MPD database"
	echo ""
	read -r -p "Command: " -n1 c
	echo ""

	if [ "$c" == "n" ]; then
		mpc_cmd next&
	elif [ "$c" == "p" ]; then
		mpc_cmd prev&
	elif [ "$c" == "" ]; then
		mpc_cmd toggle&
	elif [ "$c" == "+" ]; then
		mpc_cmd volume +5&
	elif [ "$c" == "-" ]; then
		mpc_cmd volume -5&
	elif [ "$c" == "c" ]; then
		mpc_cmd clear&
	elif [ "$c" == "d" ]; then
		mpc_cmd del 0&

	# Search any and add
	elif [ "$c" == "/" ]; then
		notify "Add music."
		read -p "Add music: " -r any
		mpc_add any "$any"&
		
	# Search and replace
	elif [ "$c" == "\\" ]; then
		notify "Replace music."
		read -p "Replace music: " -r any
		mpc_replace any "$any"&

	# Search artist and add
	elif [ "$c" == "a" ]; then
		notify "Add artist."
		read -p "Add artist: " -r artist
		mpc_add artist "$artist"&

	# Search album and add
	elif [ "$c" == "A" ]; then
		notify "Add album."
		read -p "Add album: " -r album
		mpc_add album "$album"&
		
	# Search song and add
	elif [ "$c" == "s" ]; then
		notify "Add song title."
		read -p "Add song title: " -r title
		mpc_add title "$title"&

	# Search playlist and add
	elif [ "$c" == "P" ]; then
		notify "Add playlist."
		read -p "Add playlist: " -r playlist
		mpc_add_playlist "$playlist"&
		
	elif [ "$c" == "u" ]; then
		mpc_cmd --wait update && notify "Database update finished"&
	else
		notify "Command '$c' not found"
	fi
done
