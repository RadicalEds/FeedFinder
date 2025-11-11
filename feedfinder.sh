#!/bin/bash
#####################################
VERSION="0.1"
NAME="FeedFinder"
AUTHOR="RadicalEd"
DESCRIPTION="Find Common RSS/Atom Feeds From A URL/Domain"
LICENSE=""
PROGRAM=$0
BANNERCOLOR="red"
HIGHLIGHT="red"
#####################################
# Printing Functions

c () { # Set/Clear Colors
	case "${1}" in
		(black)      tput setaf 0;;
		(red)        tput setaf 1;;
		(green)      tput setaf 2;;
		(yellow)     tput setaf 3;;
		(blue)       tput setaf 4;;
		(magenta)    tput setaf 5;;
		(cyan)       tput setaf 6;;
		(white)      tput setaf 7;;
		(bg_black)   tput setab 0;;
		(bg_red)     tput setab 1;;
		(bg_green)   tput setab 2;;
		(bg_yellow)  tput setab 3;;
		(bg_blue)    tput setab 4;;
		(bg_magenta) tput setab 5;;
		(bg_cyan)    tput setab 6;;
		(bg_white)   tput setab 7;;
		(n)          tput sgr0;;
		(none)       tput sgr0;;
		(clear)      tput sgr0;;
	esac
}

banner () {
cat << 'EOF' >&2 | sed -e "s/@/$(c magenta)@$(c n)/g"
   _______            _ _______ _           _             
  (_______)          | (_______|_)         | |            
   _____ ____ ____ _ | |_____   _ ____   _ | | ____  ____ 
  |  ___) _  ) _  ) || |  ___) | |  _ \ / || |/ _  )/ ___)
  | |  ( (/ ( (/ ( (_| | |     | | | | ( (_| ( (/ /| |    
  |_|   \____)____)____|_|     |_|_| |_|\____|\____)_|    
EOF
}


usage () {
c "$BANNERCOLOR"
banner
c n

cat << EOF >&2

$(c $HIGHLIGHT)$NAME$(c n) v$VERSION - Written By $(c $HIGHLIGHT)$AUTHOR$(c n)

$(echo -n "	$DESCRIPTION" | fmt -w $(tput cols))

$(c $HIGHLIGHT)USAGE$(c n): $PROGRAM [-h] [-c] <URL/Domain/List...>

	-c : continue checking patterns after a feed is found
	-h : show usage

EOF
}

error () {
	code="$1";shift
	case "$code" in
		(1) usage;;
	esac
	echo "Error $code: $*" >&2
	exit "$code"
}

hr () { # Horizontal Rule
	character="${1:--}"
	printf -v _hr "%*s" $(tput cols) && echo "${_hr// /$character}";
}


clearline () {
	printf "\r%*s\r" $(tput cols);
}

statusline () {
	clearline
	printf "\r$*" >&2
}

# End of Printing Functions
#####################################
# Arguments

while getopts "hc" o;do
	case "${o}" in
		(h) usage && exit;;
		(c) continue_if_found="true";;
		(*) echo "Try Using $PROGRAM -h for Help And Information" >&2 && exit 1;;
	esac
done

shift $((OPTIND-1))

[ ! "$1" ] && error 1 "We Need A <URL/Domain> to Check"

# End of Arguments
#####################################
# Functions

validate () {
	local data="$1"
	local response="$(sed -n 1p <<< "$data")"
	[[ ! "$response" =~ 200 ]] && return 1
	local content_type="$(grep "content-type" <<< "$data")"
	[[ ! "$content_type" =~ application ]] && return 1
	return 0
}

make_request () {
	# make request
	local url="$1"
	validate "$(curl --silent -I "$url")"
}

parse_domain () {
	# convert urls to their domain name
	# assume https unless told http
	local url="$1"
	protocol="https://"
	if [[ "$url" =~ ^http ]];then
		[[ ! "$url" =~ ^https ]] && protocol="http://"
		url="$(cut -d '/' -f 3 <<< "$url")"
	elif [[ "$url" =~ / ]];then
		url="${url/\/*/}"
	fi
	# ensure everything is https
	echo "$protocol$url"
}

find_feeds () {
	# loop through common feed urls
	local url="$1"
	local domain="$(parse_domain "$url")"
	patterns=(
		'feed'
		'feed/'
		'rss'
		'rss.xml'
		'feed.xml'
		'feeds/posts/default'
		'collections/all.atom'
	)
	local found="false"
	for pattern in ${patterns[@]};do
		[ "$found" == "true" ] && [ ! "$continue_if_found" ] && break
		statusline "Checking: $domain/$pattern"
		make_request "$domain/$pattern"

		case $? in
			(0) clearline && echo "$domain/$pattern" && found="true";;
		esac
	done
}

# End of Functions
#####################################
# Execution

	# Check Each URL Given, If its a File, Process it Line by Line
PIDS=()
while read url;do
	if [ -f "$url" ];then
		while read u;do
			find_feeds "$u" &
			PIDS+=($!)
		done < "$url"
	else
		find_feeds "$url" &
		PIDS+=($!)
	fi
done <<< $(printf "%s\n" "$@")

for pid in "${PIDS[@]}"; do
    wait $pid  # Wait for all tasks to finish
done

clearline

# End of Execution
#####################################
