#!/bin/sh
#
###############################################################################
#
# A script to ease playing Digitally Imported and SKY.fm Internet radio
#
# Author: Lasse Collin <lasse.collin@tukaani.org>
#
# This file has been put into the public domain.
# You can do whatever you want with this file.
#
# Last updated: 2013-03-17 17:00+0200
#
# Thanks:
#   - Antti Harri
#   - Denis Krienbühl
#
###############################################################################

# Program name to display in messages. This looks nicer than $0 which
# contains the full path.
PROG=${0##*/}

# Don't let environment variables mess up with the config.
unset BITRATE PREMIUM PLAYER MENU CHANNEL MY_CHANNELS MY_URLS

# Read the config file if it exists.
CONF=~/.difmplayrc
[ -f "$CONF" ] && . "$CONF"

# Optional channel list configuration file:
CHANNELS_CONF=~/.difmplay_channels

# Message to display with -h.
HELP="Usage: $PROG [OPTION]... [CHANNEL]
Play a stream from Digitally Imported <http://di.fm/>, SKY.fm <http://sky.fm/>,
JAZZRADIO <http://jazzradio.com/> and ROCKRADIO <http://rockradio.com>.
For high-quality streams, premium subscription is required.

  -b BITRATE        Set the bitrate as kbit/s for the premium subscription.
                    256 is MP3. 128, 64, and 40 are AAC. The default is 256.
                    If the premium ID is not set, this option is ignored and
                    the free stream is played.
  -i PREMIUM        Set the premium ID (a hexadecimal string) needed
                    to construct URLs for premium streams. You can
                    find this string by looking at the URLs of the
                    channels when logged in DI.fm or SKY.fm website.
  -p PLAYER         Set the command to use as the audio player. It has to
                    accept an URL to the playlist (.pls) as the last
                    argument. Wordsplitting is applied to PLAYER, which makes
                    it possible to pass additional command line options to
                    the player program. The default is 'mplayer -playlist'.
  -m                Display a menu using 'dialog' to select the channel
                    and bitrate. The default selections can be specified in
                    the config file or on the command line.
  -n                Don't display a menu even if config file has MENU=yes
                    or the -m option was already used.
  -l                Display the list of available channels. (May be outdated.)
  -u                Download a new channel list to ~/.difmplay_channels.
                    This may not work if the web site formatting has changed.
  -h                Display this help message.

CHANNEL may be an abbreviated name of the channel. The abbreviation has to be
unique except when setting the default selection for the menu.

Default settings can be set in ~/.difmplayrc. It is read as an 'sh' script.
Supported configuration variable names are BITRATE, PREMIUM, PLAYER, MENU
(valid values being 'yes' and 'no'), CHANNEL, MY_CHANNELS, and MY_URLS.

Custom channels can be defined in ~/.difmplayrc: MY_CHANNELS should contain
a white space separated list of channel names that don't conflict with
predefined channel names. MY_URLS should contain a list of playlist URLs.

Report bugs to <lasse.collin@tukaani.org> (in English or Finnish).
difmplay home page: <http://tukaani.org/difmplay/>"

# List of supported channels (to show the channel list and to quickly catch
# typos). You can get updated lists with difmplay -u.
#
# The first and last character in these strings must be a space for
# validation with 'case'.
CHANNELS_DI=" ambient bigroomhouse breaks chillhop chillout chilloutdreams \
chillstep chiptunes classiceurodance classiceurodisco classictechno \
classictrance classicvocaltrance club clubdubstep cosmicdowntempo darkdnb \
deephouse deepnudisco deeptech discohouse djmixes downtempolounge \
drumandbass dubstep eclectronica electro electroswing electronicpioneers epictrance \
eurodance funkyhouse futuresynthpop gabber glitchhop goapsy handsup \
hardcore harddance hardstyle hardtechno house latinhouse liquiddnb \
liquiddubstep lounge mainstage minimal moombahton oldschoolacid progressive \
progressivepsy psychill russianclubhits sankeys scousehouse soulfulhouse \
spacemusic techhouse techno trance trap tribalhouse ukgarage umfradio \
vocalchillout vocallounge vocaltrance "
CHANNELS_SKY=" 60srock 80sdance 80srock 90srnb altrock americansongbook \
beatles bebop bossanova cafedeparis christian christmas classical \
classicalpianotrios classicmotown classicrap classicrock clubbollywood \
compactdiscoveries country dancehits datempolounge dreamscapes guitar \
hardrock hit60s hit70s hit90s indierock israelihits jazzclassics jpop \
lovemusic mellowjazz metal modernblues modernrock nature newage oldies \
oldschoolfunknsoul pianojazz poppunk poprock relaxation relaxingexcursions \
romantica rootsreggae russiandance russianpop salsa ska smoothjazz \
smoothjazz247 smoothlounge softrock solopiano soundtracks the80s tophits \
uptemposmoothjazz urbanjamz vocalnewage vocalsmoothjazz world "
CHANNELS_JAZZ=" avantgarde bassjazz bebop blues bluesrock bossanova \
classicjazz cooljazz currentjazz fusionlounge guitarjazz gypsyjazz hardbop \
holidayjazz latinjazz mellowjazz pariscafe pianojazz pianotrios \
saxophonejazz sinatrastyle smoothjazz smoothjazz247 smoothlounge \
smoothuptempo smoothvocals straightahead swingnbigband timelessclassics \
trumpetjazz vibraphonejazz vocaljazz vocallegends "
CHANNELS_ROCK=" 60srock 80srock 90srock alternative80s alternative90s \
beatlestribute blackmetal bluesrock classichardrock classicmetal \
classicrock deathcore deathmetal hairbands hardcore harderrock hardrock \
heavymetal indierock jambands melodicdeathmetal metal metalcore modernrock \
numetal poppunk poprock powermetal progressivemetal progressiverock \
punkrock rapmetal rockballads screamoemo ska softrock symphonicmetal \
thrashmetal "

# Load the channel list file if it exists. It isn't validated so
# the user hopefully doesn't put nonsense into it.
[ -f "$CHANNELS_CONF" ] && . "$CHANNELS_CONF"

# MY_CHANNELS might have any amount of white space. Convert it to the same
# format as above.
CHANNELS_CUSTOM=$(echo "x$MY_CHANNELS" | tr '[:space:]' ' ' \
		| sed 's/^x//;s/ \{1,\}/ /g;s/^ */ /;s/ *$/ /')

# Updating cannot be set from the config file.
UPDATE=no

# Parse the command line arguments.
while getopts 'b:hi:lmnp:u' ARG "$@"; do
	case $ARG in
		b)
			BITRATE=$OPTARG
			;;
		h)
			echo "$HELP"
			exit 0
			;;
		i)
			PREMIUM=$OPTARG
			;;
		l)
			# Behave differently depending on if stdout is
			# a terminal or not.
			if tty -s 0>&1; then
				# column is not in POSIX but many systems
				# have it.
				echo "$CHANNELS_DI$CHANNELS_SKY$CHANNELS_JAZZ$CHANNELS_ROCK$CHANNELS_CUSTOM" \
						| tr ' ' '\n' | column
			else
				# Not writing to a terminal, so make it easier
				# to pipe the channel list to other programs.
				echo "$CHANNELS_DI$CHANNELS_SKY$CHANNELS_JAZZ$CHANNELS_ROCK$CHANNELS_CUSTOM" \
						| tr ' ' '\n' | sed '/^$/d'
			fi
			exit 0
			;;
		m)
			MENU=yes
			;;
		n)
			MENU=no
			;;
		p)
			PLAYER=$OPTARG
			;;
		u)
			UPDATE=yes
			break
			;;
		*)
			echo "Try '$PROG -h' for help." >&2
			exit 1
			;;
	esac
done

# If requested, download an updated channels list and store it
# into $CHANNELS_CONF.
if [ "$UPDATE" = "yes" ]; then
	# Stop on errors.
	set -e

	echo "$PROG: Downloading new channel lists..."

	UPDATE=$(
		echo "# Autogenerated with '$PROG -u' on $(date +%Y-%m-%d)."
		echo "# Tiny changes can break $PROG so" \
			"do not edit this file manually."
		echo

		# Get Channels using a nice format which can be directly
		# copypasted into this script when making a new release.

		# Channels from di.fm using json api.
		{
			echo 'CHANNELS_DI="'
			curl -s http://listen.di.fm/public3 | \
			grep -o '"key":"[^"]*"' | \
			sed 's/"key":"\([^"]*\)"/\1/g' | sort
		} | tr '\n' ' ' | fold -sw 76 | sed '$!s/$/\\/; $s/$/"/'
		echo
		echo

		# Channels from sky.fm using json api.
		{
			echo 'CHANNELS_SKY="'
			curl -s http://listen.sky.fm/public3 | \
			grep -o '"key":"[^"]*"' | \
			sed 's/"key":"\([^"]*\)"/\1/g' | sort
		} | tr '\n' ' ' | fold -sw 76 | sed '$!s/$/\\/; $s/$/"/'
		echo
		echo

		# Channels from jazzradio.com using json api.
		{
			echo 'CHANNELS_JAZZ="'
			curl -s http://listen.jazzradio.com/public3 | \
			grep -o '"key":"[^"]*"' | \
			sed 's/"key":"\([^"]*\)"/\1/g' | sort
		} | tr '\n' ' ' | fold -sw 76 | sed '$!s/$/\\/; $s/$/"/'
		echo
		echo

		# Channels from rockradio.com using json api.
		{
			echo 'CHANNELS_ROCK="'
			curl -s http://listen.rockradio.com/public3 | \
			grep -o '"key":"[^"]*"' | \
			sed 's/"key":"\([^"]*\)"/\1/g' | sort
		} | tr '\n' ' ' | fold -sw 76 | sed '$!s/$/\\/; $s/$/"/'
		echo
	)

	# All hopefully went fine so far. Write a new channel list file.
	echo "$UPDATE" > "$CHANNELS_CONF"
	echo "$PROG: Updated channel lists saved to $CHANNELS_CONF."
	exit 0
fi

# Set the defaults for settings not specified in the config file or
# on the command line.
MENU=${MENU:-no}
PLAYER=${PLAYER:-'mplayer -playlist'}

if [ -z "$PREMIUM" ]; then
	BITRATE=free
elif [ -z "$BITRATE" ]; then
	BITRATE=256
fi

# Non-option arguments currently include only the channel name.
shift $(expr $OPTIND - 1)
case $# in
	0)
		# Using the default channel from the config file.
		if [ -z "$CHANNEL" -a "$MENU" = "no" ]; then
			echo "$PROG: No channel was specified in the config" \
					"file or on the command line." >&2
			echo "Try '$PROG -h' for help." >&2
			exit 1
		fi
		;;
	1)
		CHANNEL=$1
		;;
	*)
		echo "$PROG: Too many command line arguments." >&2
		echo "Try '$PROG -h' for help." >&2
		exit 1
		;;
esac

# Validate the bitrate.
case $BITRATE in
	40|64|128|256|free) ;;
	*)
		echo "$PROG: Supported bitrates are 256, 128, 64, and 40." >&2
		exit 1
		;;
esac

# Roughly validate the channel name so that it doesn't cause us problems.
case $CHANNEL in
	*" "*|*"'"*)
		echo "$PROG: Channel name must not contain spaces or" \
				"quote characters." >&2
		echo "Use '$PROG -l' to view the list of channels." >&2
		exit 1
		;;
esac

# See if the given channel name matches a known channel name. The channel
# name can be abbreviated, and it has to be unique unless we are going to
# display a menu.
MATCH=
for ARG in $CHANNELS_DI$CHANNELS_SKY$CHANNELS_JAZZ$CHANNELS_ROCK$CHANNELS_CUSTOM; do
	case $ARG in
		"$CHANNEL")
			# Exact channel name was found.
			MATCH=$ARG
			break
			;;
		"$CHANNEL"*)
			# Abbreviated channel name was found.
			if [ -n "$MATCH" ]; then
				# If we are using a menu, don't complain
				# about ambiguous channel names, but keep
				# looking for exact match.
				[ "$MENU" = "yes" ] && continue
				echo "$PROG: '$CHANNEL' is ambiguous." >&2
				echo "Use '$PROG -l' to view the list" \
						"of channels." >&2
				exit 1
			fi
			MATCH=$ARG
			;;
	esac
done

# If we are going to display a menu, it's OK if we found no channel name.
if [ -z "$MATCH" -a "$MENU" = "no" ]; then
	echo "$PROG: Unknown channel name: $CHANNEL" >&2
	echo "Use '$PROG -l' to view the list of channels." >&2
	exit 1
fi
CHANNEL=$MATCH

# Display the menu if requested.
if [ "$MENU" = "yes" ]; then
	# Ask for the channel.
	MENUCMD="dialog --backtitle $PROG --default-item '$CHANNEL'"
	MENUCMD="$MENUCMD --menu 'Select the channel:' 19 32 12"
	for ARG in $CHANNELS_DI$CHANNELS_SKY$CHANNELS_JAZZ$CHANNELS_ROCK$CHANNELS_CUSTOM; do
		MENUCMD="$MENUCMD $ARG ''"
	done
	CHANNEL=$(eval "$MENUCMD" 3>&1 1>&2 2>&3) || exit 1

	# Ask for the bitrate only when using premium.
	if [ -n "$PREMIUM" ]; then
		MENUCMD="dialog --backtitle $PROG --default-item $BITRATE"
		MENUCMD="$MENUCMD --menu 'Select the bitrate:' 11 32 4"
		MENUCMD="$MENUCMD 256 'MP3 256 kbit/s' 128 'AAC 128 kbit/s'"
		MENUCMD="$MENUCMD 64 'AAC  64 kbit/s' 40 'AAC  40 kbit/s'"
		BITRATE=$(eval "$MENUCMD" 3>&1 1>&2 2>&3) || exit 1
	fi

	echo
fi

# Construct the URL of the playlist.
# TODO: This should be rewritten...
case $CHANNELS_DI in
	*" $CHANNEL "*)
		WEBSITE=di
		;;
	*)
		case $CHANNELS_SKY in
			*" $CHANNEL "*)
				WEBSITE=sky
				;;
			*)
				case $CHANNELS_JAZZ in
					*" $CHANNEL "*)
						WEBSITE=jazz
						;;
					*)
						case $CHANNELS_ROCK in
							*" $CHANNEL "*)
								WEBSITE=rock
								;;
							*)
								WEBSITE=custom
								;;
						esac
						;;
				esac
				;;
		esac
		;;
esac
case $WEBSITE$BITRATE in
	di256)    URL="http://listen.di.fm/premium_high/$CHANNEL.pls?$PREMIUM" ;;
	di128)    URL="http://listen.di.fm/premium/$CHANNEL.pls?$PREMIUM" ;;
	di64)     URL="http://listen.di.fm/premium_medium/$CHANNEL.pls?$PREMIUM" ;;
	di40)     URL="http://listen.di.fm/premium_low/$CHANNEL.pls?$PREMIUM" ;;
	difree)   URL="http://listen.di.fm/public3/$CHANNEL.pls" ;;
	sky256)   URL="http://listen.sky.fm/premium_high/$CHANNEL.pls?$PREMIUM" ;;
	sky128)   URL="http://listen.sky.fm/premium/$CHANNEL.pls?$PREMIUM" ;;
	sky64)    URL="http://listen.sky.fm/premium_medium/$CHANNEL.pls?$PREMIUM" ;;
	sky40)    URL="http://listen.sky.fm/premium_low/$CHANNEL.pls?$PREMIUM" ;;
	skyfree)  URL="http://listen.sky.fm/public3/$CHANNEL.pls" ;;
	jazz256)  URL="http://listen.jazzradio.com/premium_high/$CHANNEL.pls?$PREMIUM" ;;
	jazz128)  URL="http://listen.jazzradio.com/premium/$CHANNEL.pls?$PREMIUM" ;;
	jazz64)   URL="http://listen.jazzradio.com/premium_medium/$CHANNEL.pls?$PREMIUM" ;;
	jazz40)   URL="http://listen.jazzradio.com/premium_low/$CHANNEL.pls?$PREMIUM" ;;
	jazzfree) URL="http://listen.jazzradio.com/public3/$CHANNEL.pls" ;;
	rock256)  URL="http://listen.rockradio.com/premium_high/$CHANNEL.pls?$PREMIUM" ;;
	rock128)  URL="http://listen.rockradio.com/premium/$CHANNEL.pls?$PREMIUM" ;;
	rock64)   URL="http://listen.rockradio.com/premium_medium/$CHANNEL.pls?$PREMIUM" ;;
	rock40)   URL="http://listen.rockradio.com/premium_low/$CHANNEL.pls?$PREMIUM" ;;
	rockfree) URL="http://listen.rockradio.com/public3/$CHANNEL.pls" ;;
	custom*)
		# Set URL from MY_URLS so that there is exactly one space
		# between URLs and no space in the beginning or end of
		# the string.
		URL=$(echo "$MY_URLS" | tr '[:space:]' ' ' \
				| sed 's/ \{1,\}/ /g;s/^ *//;s/ *$//')

		# Set I to contain as many spaces as the index of the selected
		# custom channel is.
		I=$(echo "${CHANNELS_CUSTOM%" $CHANNEL "*}" | tr -dc ' ')

		# Remove as many URLs from the beginning of the $URL as there
		# are spaces in $I.
		while [ -n "$I" ]; do
			I=${I%' '}
			URL=${URL#*' '}
		done

		# Remove the trailing URLs.
		URL=${URL%%' '*}
		;;
esac

# Try to play it.
exec $PLAYER "$URL"

# Just in case it failed, make sure we give a reasonable exit status.
exit 1
