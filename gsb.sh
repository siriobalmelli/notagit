#!/bin/bash

# input validation regeces ;)
REPO_VAL='[a-zA-Z_-]+'
USER_VAL='[a-zA-Z_-]+'
KEY_VAL='ssh-[rd]sa \S+ \S+'

usage()
{
	echo -e "usage:
$0 [-v|--verbose] [-i|--inactive]
	[-q|--quota MB]		repo	{ls|add|disable|rm}	REPO
				user	{ls|add|disable|rm}	USER
				key	{ls|add|rm}		USER KEY
	[-w|--write]		auth	{ls|add|rm}		USER REPO

Field definition (RegEx):
REPO	:=	'$REPO_VAL'
USER	:=	'$USER_VAL'
KEY	:=	'$KEY_VAL' || {filename}

NOTES:
	- script should be run with root privileges.
	- KEY must be quoted (or must be a file)
	- quotas not implemented yet
" >&2
}


# static assumptions
REPO_BASE="/usr/src/git"	# active repos go here
ARCH_BASE="/usr/src/archive"	# disabled repos go here


# get arguments
QUOTA_=
WRITE_=
DBG_=
INACTIVE_=
while [[ "$1" \
	&& "$1" != "repo" \
	&& "$1" != "user" \
	&& "$1" != "auth" \
	&& "$1" != "key" ]]
do
	case $1 in
	-v|--verbose)
		DBG_="-v" # do double-duty as a command flag ;)
		DEBUG_PRN_="debugging enabled:	$*"
		shift
		;;
	-i|--inactive)
		INACTIVE_='#' # do double-duty as a leading comment in /etc/fstab ;)
		shift
		;;
	-q|--quota)
		DEBUG_PRN_="got quota of $2"
		QUOTA_="$2"
		echo "quotas not yet implemented" >&2
		exit 1
		shift; shift
		;;
	-w|--write)
		DEBUG_PRN_="write"
		WRITE_=1
		shift
		;;
	*)
		echo "Unknown option '$1'" >&2
		usage
		exit 1
		;;
	esac
	# optional argument debug print
	if [[ $DBG_ ]]; then
		echo "$DEBUG_PRN_"
	fi
done
# disabled users have '.ssh/disabled', active ones have 'authorized_keys' instead
if [[ $INACTIVE_ ]]; then
	COND_=".ssh/disabled"
else
	COND_=".ssh/authorized_keys"
fi




##########################################################
##			repo utilities			##
##########################################################

#	repo_exists_()
#		$1	:	REPO
#		$2	:	quiet? (use as internal function, don't output errors)
repo_exists_()
{
	# ignore null input
	if [[ -z "$1" ]]; then return 1; fi

	# verify toplevel dir exists
	if [[ ! -d "$REPO_BASE/$1" ]]; then
		if [[ -z "$2" ]]; then
			echo "Repo '$1' doesn't exist. Cannot archive" >&2
		fi
		return 1
	fi
	# verify it is, in fact, a git repo
	if [[ ! -e "$REPO_BASE/$1/HEAD" ]]; then
		if [[ -z "$2" ]]; then
			echo "'$REPO_BASE/$1' exists but is not a valid Git repo" >&2
		fi
		return 1
	fi

	return 0
}




##########################################################
##			user utilities			##
##########################################################

#	user_umount_()
#		$1	:	USER
# Internal utility: unmount all repos for a certain user
user_umount_()
{
	mount | grep "/home/$2" | cut -d ' ' -f 3 | xargs -I{} umount -f $DBG_ {}
}

#	user_exists_()
#		$1	:	USER
#		$2	:	quiet? (use as internal function, don't output errors)
user_exists_()
{
	# ignore null input
	if [[ -z "$1" ]]; then return 1; fi

	# user must exist and must have the proper shell
	if ! getent passwd | grep -E "^$1:.*git-shell$" >/dev/null; then
		if [[ -z "$2" ]]; then
			echo "user '$1' doesn't exist or doesn't log into git-shell" >&2
		fi
		return 1
	fi
	# if INACTIVE_ then user MUST be inactive, and vice-versa
	if [[ "$INACTIVE_" && ! -e "/home/$1/.ssh/disabled" ]]; then
		if [[ -z "$2" ]]; then
			echo "'-i|--inactive' set but user '$1' not disabled"
		fi
		return 1
	elif [[ ! "$INACTIVE_" && -e "/home/$1/.ssh/disabled" ]]; then
		if [[ -z "$2" ]]; then
			echo "no flag '-i|--inactive' but user '$1' disabled"
		fi
		return 1
	fi

	return 0
}

#	user_ssh_perms_()
#		$1	:	USER
user_ssh_perms_()
{
	# mark user changed
	touch "/home/$1/$COND_"
		poop=$?; if (( $poop )); then exit $poop; fi

	# force ownership and permissions
	chown $DBG_ -R "$1": "/home/$1/.ssh"
		poop=$?; if (( $poop )); then exit $poop; fi
	chmod $DBG_ -R ugo-rwx,u+rX "/home/$1/.ssh"
		poop=$?; if (( $poop )); then exit $poop; fi
	# force ownership and permissions
	chown $DBG_ -R "$1": "/home/$1/.ssh"
		poop=$?; if (( $poop )); then exit $poop; fi
	chmod $DBG_ -R ugo-rwx,u+rX "/home/$1/.ssh"
		poop=$?; if (( $poop )); then exit $poop; fi
}




##########################################################
##			generic utilities		##
##########################################################

#	check_platform()
#
# Verify that all required platform components are copacetic
check_platform()
{
	# can only run on a Linux ATM
	if ! uname -s | grep "Linux" >/dev/null; then
		echo "$(uname -s) is not a Linux?" >&2
		exit 1
	fi

	# must be root
	if [[ $(whoami) != "root" ]]; then
		echo "must run as root" >&2
		exit 1
	fi

	# SSH should ideally NOT allow password logins
	if grep -E "^[^#]+asswordAuthentication\s+yes" /etc/ssh/sshd_config >/dev/null; then
		echo "WARNING: your ssh server allows password logins. Please consider disabling this." >&2
	fi
	#TODO verify REPO_BASE exists on an FS mounted with quotas and "noexec"
}

#	mount_refresh_()
#		$1	:	USER | REPO
#
# Cleanest way to make sure permissions changes are propagated and
#	weird corner cases are avoided.
mount_refresh_()
{
	# Unmounts any instances connected to '$1'
	if user_exists_ "$1" "quiet"; then
		mount | grep "/home/$1" | cut -d ' ' -f 1 | xargs -I{} umount -f {}
	elif repo_exists_ "$1" "quiet"; then
		mount | grep "$REPO_BASE/$1" | cut -d ' ' -f 1 | xargs -I{} umount -f {}
	fi

	# mount things according to fstab
	mount -a $DBG_
		poop=$?; if (( $poop )); then exit $poop; fi
}




##########################################################
##			primary functions 		##
##########################################################

#	repo()
#
#		$1	:	{ls|add|archive|exhume}
#		$2	:	REPO
#
# TODO implement quotas
repo()
{
	# 	list
	# Show either active or inactive repos, user $2 as a filter string
	if [[ "$1" == "ls" || "$1" == "list" ]]; then
		# list active or inactive repos?
		if [[ ! $INACTIVE_ ]]; then
			SEARCH_="$REPO_BASE"
		else
			SEARCH_="$ARCH_BASE"
		fi
		# list them
		find "$SEARCH_" -mindepth 1 -maxdepth 1 -type d ! -name "lost+found" \
				-exec basename '{}' \; \
			| grep "$2" \
			| sort
		return $?
	fi

	# all other invocations besides "list" require REPO
	if ! echo "$2" | grep -E "$REPO_VAL" >/dev/null; then
		echo "repo() expects: $1 REPO" >&2
		usage
		exit 1
	fi
	if getent passwd "$2" || getent group "$2"; then
		echo "repo cannot be named identically to a user or group" >&2
		exit 1
	fi

	# force existence of REPO and ARCH
	mkdir -p $DBG_ "$REPO_BASE" "$ARCH_BASE"
		poop=$?; if (( $poop )); then exit $poop; fi
	chown $DBG_ root: "$REPO_BASE" "$ARCH_BASE"
		poop=$?; if (( $poop )); then exit $poop; fi
	chmod $DBG_ u=rwx,go-rwx "$REPO_BASE" "$ARCH_BASE"
		poop=$?; if (( $poop )); then exit $poop; fi

	case $1 in
		#	add
		# add a new repository;
		# reactivate a disabled repo;
		# validate/force settings on an existing active repo.
		new|add|en|enable)
			# repo dir doesn't currently exist
			if [[ ! -d "$REPO_BASE/$2" ]]; then

				# if it exists but is disabled, move it back
				if [[ -d "$ARCH_BASE/$2" ]]; then
					mv $DBG_ "$ARCH_BASE/$2" "$REPO_BASE/$2"
					poop=$?; if (( $poop )); then exit $poop; fi
					# restore fstab entries for repo
					cat "$ARCH_BASE/${2}.mounts" >>/etc/fstab
					rm -f $DBG_ "$ARCH_BASE/${2}.mounts"
					sort -o /etc/fstab /etc/fstab

				# no? create it
				else
					mkdir $DBG_ "$REPO_BASE/$2"
					poop=$?; if (( $poop )); then exit $poop; fi
					pushd "$REPO_BASE/$2"
					git init --bare
					poop=$?; if (( $poop )); then popd; rm -rf "$REPO_BASE/$2"; exit $poop; fi
				fi
			fi

			# make sure repo-specific group exists
			if ! getent group "git_$2" >/dev/null; then
				addgroup --force-badname "git_$2"
					poop=$?; if (( $poop )); then exit $poop; fi
			fi

			# force ownership and permissions on repo dir
			chown -R nobody:"git_$2" "$REPO_BASE/$2"
				poop=$?; if (( $poop )); then exit $poop; fi
			chmod -R u=rwX,g=rwXs,o=rX,o-w "$REPO_BASE/$2" # notice group sticky bit
				poop=$?; if (( $poop )); then exit $poop; fi
			# This is to allow git to write temporary account stuff
			#+	when a read-only user pulls
			# TODO any way around this? (if so, change fstab mount stanza to say "r"
			chmod o+w "$REPO_BASE/$2"
				poop=$?; if (( $poop )); then exit $poop; fi

			# refresh mounts
			mount_refresh_ "$2"
			;;

		#	disable
		# Archive an existing repo; disable access by users but save
		#+	their ~/[repo] mountpoints intact for later restoration.
		# NOTE that some mountpoints may have been DISABLED, we need to preserve this.
		dis|disable)
			# verify repo exists in the first place
			if ! repo_exists_ "$2"; then exit 1; fi

			# verify no archived project by the same name
			if [[ -d "$ARCH_BASE/$2" ]]; then
				echo "Archived repo '$2' already exists." >&2
				exit 1
			fi

			# preserve mount entries from fstab
			sed -rn '\|'"$REPO_BASE/$2"'| p' /etc/fstab >"$ARCH_BASE/${2}.mounts"
			# recurse: purge mounts
			repo purge_mounts $2

			# move repo to archive
			mv $DBG_ "$REPO_BASE/$2" "$ARCH_BASE/$2"
				poop=$?; if (( $poop )); then exit $poop; fi
			;;

		#	rem
		# Remove a repo entirely; whether archived or active
		rm|rem|del|delete)
			if ! repo_exists_ "$2"; then exit 1; fi

			# purge mounts
			repo purge_mounts $2
			# remove all mount dirs
			find /home -type d -name "$2" -exec rm -rf $DBG_ '{}' \; 2>/dev/null

			# remove repo and/or archive dir, archived mounts list
			rm -rf $DBG_ "$REPO_BASE/$2" "$ARCH_BASE/${2}*"

			#remove group
			groupdel "git_$2"
				poop=$?; if (( $poop )); then exit $poop; fi
			;;

		#	purge_mounts
		# unmount any bind-mounts pointing at repo, remove them from fstab
		purge_mounts)
			# unmount all instances of repo
			find /home -type d -name "$2" -exec umount -f $DBG_ '{}' 2>/dev/null \;
			# delete them, and empty lines, too
			sed -i"" -re '\|'"$REPO_BASE/$2"'| d' -e '/^\s*$/ d' /etc/fstab
			;;

		*)
			echo "Unknown command '$1'" >&2
			usage
			exit 1
			;;
	esac
}


#	user()
#		$1	:	{ls|add|disable|rem}
#		$2	:	USER
user()
{
	# 	list
	# Show either active or inactive users
	if [[ "$1" == "ls" || "$1" == "list" ]]; then
		# only go through "git-shell" users; user $2 as a filter string
		for u in $(getent passwd | grep "${2}.*git-shell" | cut -d ':' -f 1 | sort); do
			if [[ -e "/home/$u/$COND_" ]]; then
				echo $u
				if [[ "$KEY_" == "1" ]]; then
					cat /home/$u/$COND_
				fi
			fi
		done
		#done
		return 0
	fi

	# all other commands require USER
	if ! echo "$2" | grep -E "$USER_VAL" >/dev/null; then
		echo "user() expects: $1 USER" >&2
		usage
		exit 1
	fi

	case $1 in
		#	add
		# Add a new user; Enable a previously disabled user; Validate a user.
		# An active user can ONLY log in via SSH, to a git-shell.
		new|add|en|enable)
			# if no user, create
			if ! getent passwd $2 >/dev/null; then
				adduser --shell /usr/bin/git-shell --disabled-password --gecos "" "$2"
			# otherwise, force git-shell
			else
				usermod -s /usr/bin/git-shell "$2" 2>/dev/null
			fi
			# ensure there are no enabled git-shell commands
			rm -f $DBG_ "/home/$2/git-shell-commands"

			# Force proper SSH directory structure.
			mkdir -p $DBG_ "/home/$2/.ssh"
				poop=$?; if (( $poop )); then exit $poop; fi
			# If user was previously disabled, restore the "disabled" file
			#+	in ~/.ssh
			if [[ -e "/home/$2/.ssh/disabled" ]]; then
				mv $DBG_ "/home/$2/.ssh/disabled" "/home/$2/.ssh/authorized_keys"
				poop=$?; if (( $poop )); then exit $poop; fi
			fi
	
			# handle SSH directory permissions
			user_ssh_perms_ "$2"

			# enable any commented-out mount entries for user
			sed -i"" -r 's|^#('"$REPO_BASE"'.*/home/'"$2"'.*)|\1|g' /etc/fstab
			sort -o /etc/fstab /etc/fstab
			# update mounts
			mount_refresh_ "$2"
			;;

		#	disable
		# To disable a user, rename their authorized_keys file
		dis|disable)
			# user must exist and be inactive/enabled according to '-i' flag
			if ! user_exists_ "$2"; then exit 1; fi

			# rename authorized_keys file
			if [[ -e "/home/$2/.ssh/authorized_keys" ]]; then
				mv "/home/$2/.ssh/authorized_keys" "/home/$2/.ssh/disabled"
				poop=$?; if (( $poop )); then exit $poop; fi
			fi

			# unmount repos
			user_umount_ "$2"
			# disable any mount entries for user
			sed -i"" -r 's|^('"$REPO_BASE"'.*/home/'"$2"'.*)|#\1|g' /etc/fstab
			;;

		#	rem
		# Remove a user entirely
		rm|rem|del|delete)
			# user must exist and be inactive/enabled according to '-i' flag
			if ! user_exists_ "$2"; then exit 1; fi

			# remove user
			deluser "$2"
				poop=$?; if (( $poop )); then exit $poop; fi

			# unmount repos
			user_umount_ "$2"
			# remove all mount entries
			sed -i"" -r '\|.*'"/home/$2"'.*| d' /etc/fstab

			# remove home dir
			rm -rf $DBG_ "/home/$2"
				poop=$?; if (( $poop )); then exit $poop; fi
			;;

		*)
			echo "Unknown command '$1'" >&2
			usage
			exit 1
			;;
	esac
}


#	key()
#		$1	:	{ls|add|rem}
#		$2	:	USER
#		$3	:	KEY
key()
{
	# 	list
	# Show keys for either active or inactive user(s), use $2 as a filter
	if [[ "$1" == "ls" || "$1" == "list" ]]; then
		for u in $(getent passwd | grep "${2}.*git-shell" | cut -d ':' -f 1 | sort); do
			# only show users who are enabled/disabled as per '-i' flag
			if [[ -e /home/$u/$COND_ ]]; then
				# print user, and optionally contents of the proper auth_keys file
				echo "$u"
				if [[ $DBG_ ]]; then
					cat /home/$u/$COND_		
				else
					sed -rn 's/.*(ssh-[rd]sa) \S+(\S{24}) (\S+)$/\t\1 ...\2 \3/p' /home/$u/$COND_
				fi
			fi
		done
		return 0
	fi

	#validate USER
	#	validate that we have USER
	if ! echo "$2" | grep -E "$USER_VAL" >/dev/null; then
		echo "key() expects: $1 USER KEY" >&2
		usage
		exit 1
	fi
	# user must exist and be inactive/enabled according to '-i' flag
	if ! user_exists_ "$2"; then exit 1; fi

	 #because key may show up as multiple fields
	CMD_="$1";
	USR_="$2";
	shift; shift

	# Try and parse KEY_ either:
	#+		- from command line directly
	#+		- from a file
	#+		- from USER's existing authorized_keys
	#+	... using KEY_VAL as the validation RegEx in all cases.
	KEY_=
	if echo "$*" | grep -E "$KEY_VAL" >/dev/null; then
		KEY_="$(echo "$*" |  sed -rn "s/.*($KEY_VAL).*/\1/p")"
	elif [[ -e "$1" ]]; then
		KEY_=$(sed -rn "s|($KEY_VAL)|\1|p" "$1")
	else
		# Apparently illogical pipe of grep through sed
		#+	because '$3' likely contains '+' and '/' chars.
		KEY_="$(grep "$1" /home/$USR_/$COND_ | sed -rn "s/.*($KEY_VAL).*/\1/p")"
	fi
	# validate obtained key
	if ! echo "$KEY_" | grep -E "$KEY_VAL" >/dev/null; then
		echo "key '$KEY_' invalid" >&2
		usage
		exit 1
	fi

	case $CMD_ in
		#	add
		# Add $KEY_ to user $USR_
		new|add|en|enable)
			echo "no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-user-rc $KEY_" \
				>> "/home/$USR_/$COND_"
			poop=$?; if (( $poop )); then exit $poop; fi
			# sort and de-dup keys
			sort -u -o "/home/$USR_/$COND_" "/home/$USR_/$COND_"
			# ssh directory is kosher
			user_ssh_perms_ "$USR_"
			;;

		#	rem
		# Rem $KEY_ from user $USR_
		rm|rem|del|delete)
			# Avoid 'sed -i' because it will barf on "+" and "/" characters
			#+	in the key itself.
			grep -v "$KEY_" "/home/$USR_/$COND_" >"/home/$USR_/${COND_}.temp"
			mv "/home/$USR_/${COND_}.temp" "/home/$USR_/$COND_"
			# ssh directory is kosher
			user_ssh_perms_ "$USR_"
			;;

		*)
			echo "Unknown command '$CMD_'" >&2
			usage
			exit 1
			;;
	esac
}


#	auth()
#		$1	:	{ls|add|rem}
#		$2	:	USER
#		$3	:	REPO
auth()
{
	# 	list
	# Show either active or inactive authorizations, use $2 as a filter
	if [[ "$1" == "ls" || "$1" == "list" ]]; then
		if [[ ! $INACTIVE_ ]]; then
			ARR=( $(sed -rn 's|^\s*'"$REPO_BASE"'/(\S+)\s+/home/([^/]+).*|\1/\2|p' /etc/fstab \
					| grep "$2") )
		else
			ARR=( $(sed -rn 's|^\s*#\s*'"$REPO_BASE"'/(\S+)\s+/home/([^/]+).*|\1/\2|p' /etc/fstab \
					| grep "$2") )
		fi
		# print, marking write-enabled auths with 'w'
		for i in ${ARR[@]}; do
			# Apologies for making the delimiter '/', but it's the ONE character
			#+	I'm sure won't show up in either repo or user names.
			if getent group git_${i/%\/*/} | grep ${i/#*\//} >/dev/null; then
				W="w"
			else
				W=""
			fi
			printf "${i/%\/*/} ${i/#*\//} $W\n"
		done | column -t
		return 0
	fi

	# all other calls must give USER and REPO
	if ! echo "$2" | grep -E "$USER_VAL" >/dev/null || ! echo "$3" | grep -E "$REPO_VAL" >/dev/null
	then
		echo "auth() expects: $1 USER REPO" >&2
		usage
		exit 1
	fi

	# user must exist and be inactive/enabled according to '-i' flag
	if ! user_exists_ "$2"; then exit 1; fi
	# repo must exist
	if ! repo_exists_ "$3"; then exit 1; fi

	case $1 in
		#	add
		# Allow/verify that user $2 can access repo $3
		new|add|en|enable)
			# add user to repo-specific group so they can write?
			if [[ $WRITE_ ]]; then
				usermod -s /usr/bin/git-shell -a -G "git_$3" "$2"
				poop=$?; if (( $poop )); then exit $poop; fi
			# in case user COULD write previosly, disable this
			else
				deluser "$2" "git_$3" 2>/dev/null
			fi

			# make sure a mountpoint exists for the bind mount
			mkdir -p $DBG_ "/home/$2/$3"
				poop=$?; if (( $poop )); then exit $poop; fi
			# Make sure fstab entry exists for bind mount, 
			#+	use 'while' to ensure its printed either way.
			# NOTE that we insert a commented-out entry if user is disabled/inactive
			while ! grep -E "/home/$2/$3" /etc/fstab; do
				printf "${INACTIVE_}$REPO_BASE/$3\t/home/$2/$3\tnone\tbind,noexec,nobootwait\t0\t0" >>/etc/fstab
				sort -o /etc/fstab /etc/fstab
			done
			# update mounts
			mount_refresh_ "$3"
			;;

		#	rem
		# Remove access to repo $3 for user $2
		rm|rem|del|delete)
			# unmount bind if mounted
			if mount | grep "/home/$2/$3" >/dev/null; then
				umount -f $DBG_ "/home/$2/$3"
				poop=$?; if (( $poop )); then exit $poop; fi
			fi

			# remove entry from fstab (whether commented out or not)
			sed -i"" -r '\|/home/'"$2/$3"'| d' /etc/fstab

			# remove user from group
			deluser "$2" "git_$3"
			;;

		*)
			echo "Unknown command '$1'" >&2
			usage
			exit 1
			;;
	esac
}




##########################################################
##			main				##
##########################################################

check_platform
case $1 in
repo)
	shift
	repo $*
	;;
user)
	shift
	user $*
	;;
auth)
	shift
	auth $*
	;;
key)
	shift
	key $*
	;;
*)
	echo "Unknown command '$1'" >&2
	usage
	exit 1
	;;
esac
