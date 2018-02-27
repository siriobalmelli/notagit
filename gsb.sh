#!/bin/bash

# input validation regeces ;)
REPO_VAL='[a-zA-Z_-]+'
USER_VAL='[a-zA-Z_-]+'
KEY_VAL='ssh-[rd]s[as] \S+ \S+'


usage()
{
	echo -e "usage:
$0 [-v|--verbose] [-?|-h|--help]
	repo	{ls|add|mod|rm}	REPO		[-a|--archived] [-q|--quota <QUOTA>]
	user	{ls|add|mod|rm}	USER		[-d|--disabled]
	key	{ls|add|mod|rm}	USER KEY	[-d|--disabled]
	auth	{ls|add|mod|rm}	USER REPO	[-a|--archived] [-d|--disabled]	[-w|--write]
	dump
	sync			REMOTE_HOST

Field definition (RegEx):
REPO	:=	'$REPO_VAL'
USER	:=	'$USER_VAL'
KEY	:=	'$KEY_VAL' || {filename}

NOTES:
	- 'add' implies \"create if not existing, modify if existing\"
		and is synonymous with 'mod'.
	- script should be run with root privileges.
	- use '-v|--verbose' flag to pipe $0 output back to input,
		e.g. to restore a backup or sync two systems
" >&2
}


##########################################################
##		internal/script utilities		##
##########################################################

#	echo_q()
#		$1	:	message
#		$2	:	quiet?
# Echo an error message to console, unless the $2 "quiet" flag is set
echo_q()
{
	if [[ -z $2 ]]; then
		echo "$1" >&2
	fi
}

#	echo_die()
#		$1	:	message
# Echo error message to the console and then exit abnormally
echo_die()
{
	echo "$1" >&2
	exit 1
}


#	do_die()
#		$*	:	command
# Execute $*, aborting if result is non-zero
do_die()
{
	$*
	poop=$?
	if (( $poop )); then
		echo "failed: $*" >&2
		exit $poop
	fi
}


##########################################################
##			repo utilities			##
##########################################################

#	repo_exists_()
#		$1	:	REPO
#		$2	:	quiet? (use as internal function, don't output errors)
# Checks if '$1' exists in '$REPO_'
#+	(which may be .../git or .../archive, depending on flags).
# Returns 0 on success.
repo_exists_()
{
	# ignore null input
	if [[ -z "$1" ]]; then return 1; fi

	# verify toplevel dir exists
	if [[ ! -d "$REPO_/$1" ]]; then
		echo_q "Repo '$1' doesn't exist in '$REPO_'" $2
		return 1
	fi
	# verify it is, in fact, a git repo
	if [[ ! -e "$REPO_/$1/HEAD" ]]; then
		echo_q "'$REPO_BASE/$1' exists but is not a valid Git repo" $2
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
	mount | grep "/home/$2" | cut -d ' ' -f 3 | xargs -I{} umount -f $V_ {}
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
		echo_q "user '$1' doesn't exist or doesn't log into git-shell" $2
		return 1
	fi

	# ls -la expected to give PRECISELY 4 lines, e.g.:
	#+	total 12K
	#+	dr-x------ 2 gitty gitty 4.0K Feb 17 23:32 .
	#+	drwxr-xr-x 5 gitty gitty 4.0K Feb 17 13:35 ..
	#+	-r-------- 1 gitty gitty 1.2K Feb 17 23:53 authorized_keys
	if [[ $(ls -la "/home/$1/.ssh" | wc -l) != 4 ]]; then
		echo_q "file-count in '/home/$1/.ssh' not EXACTLY 3; possible insecure condition" $2
		return 1
	fi
	# user must have PROPER keys file (depending on whether "active" or not)
	if [[ ! -e /home/$1/$COND_ ]]; then
		echo_q "expecting '$COND_' for user '$1'; is the '-i' flag correctly set?" $2
		return 1
	fi

	return 0
}

#	user_ssh_perms_()
#		$1	:	USER
user_ssh_perms_()
{
	# mark user changed
	do_die touch "/home/$1/$COND_"

	# force ownership and permissions
	do_die chown $V_ -R "$1": "/home/$1/.ssh"
	do_die chmod $V_ -R ugo-rwx,u+rX "/home/$1/.ssh"
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
		mount | grep "/home/$1" | cut -d ' ' -f 1 | xargs -I{} umount -f $V_ {}
	elif repo_exists_ "$1" "quiet"; then
		mount | grep "$REPO_/$1" | cut -d ' ' -f 1 | xargs -I{} umount -f $V_ {}
	fi

	# mount things according to fstab
	do_die mount -a -t none $V_ | grep -v ignored
}


##########################################################
##		primary functions (aka: "modes")	##
##########################################################

#	repo()
#
#		$1	:	{ls|add|mod|rm}
#		$2	:	REPO
#
# TODO implement quotas
repo()
{
	# 	list
	# Show either active or inactive repos, user $2 as a filter string
	if [[ "$1" == "ls" || "$1" == "list" ]]; then
		# list active or inactive repos?
		if [[ $V_ ]]; then
			DUMP_="repo add "
		fi

		# list them
		for r in $(find "$REPO_" -mindepth 1 -maxdepth 1 -type d ! -name "lost+found" \
				-exec basename '{}' \; \
			| grep "$2" \
			| sort)
		do
			echo "${DUMP_} $r ${A_}"
		done | column -t
		return
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

	# force existence base directory
	do_die mkdir -p $V_ "$REPO_"
	do_die chown $V_ root: "$REPO_"
	do_die chmod $V_ u=rwx,go-rwx "$REPO_"

	case $1 in
		#	add
		# force a repo to exist and have the proper archived|active state
		add|mod)
			# repo dir doesn't currently exist
			if ! repo_exists_ "$2" "quiet"; then
				# check for homonymous directory
				if [[ -d "$REPO_/$2" ]]; then
					echo_die "'$REPO_/$2' already exists but is not a Git repo"
				fi

				# if it exists but is on the "other side", move it
				if [[ -d "$REPO_OTHER_/$2" ]]; then
					do_die mv $V_ "$REPO_OTHER_/$2" "$REPO_/$2"
					# was archived? restore fstab entries for repo
					if [[ -e "$REPO_OTHER_/${2}.mounts" ]]; then
						# sed call necessary because some auths
						#+	may have been added while repo was archived.
						sed -e 's|'"$REPO_OTHER_"'|'"$REPO_"'|g' \
							"$REPO_OTHER_/${2}.mounts" >>/etc/fstab
						rm -f $V_ "$REPO_OTHER_/${2}.mounts"
						sort -o /etc/fstab /etc/fstab
					# we are archiving: preserve fstab entries
					else
						touch "$REPO_/${2}.mounts"
						do_die chmod go-rwx "$REPO_/${2}.mounts"
						sed -rn 's|^'"$REPO_OTHER_/$2"'(\s.*)|'"$REPO_/$2"'\1|p' \
							/etc/fstab >"$REPO_/${2}.mounts"
						# recurse: purge mounts
						repo purge_mounts $2
					fi

				# no? create it
				else
					do_die mkdir $V_ "$REPO_/$2"
					pushd "$REPO_/$2"
					do_die git init --bare
				fi
			fi

			# make sure repo-specific group exists
			if ! getent group "git_$2" >/dev/null; then
				do_die addgroup --force-badname "git_$2" \
					| grep -v "Done"
			fi

			# force ownership and permissions on repo dir
			do_die chown -R nobody:"git_$2" "$REPO_/$2"
			do_die chmod -R u=rwX,g=rwXs,o=rX,o-w "$REPO_/$2" # notice group sticky bit
			# This is to allow git to write temporary account stuff
			#+	when a read-only user pulls
			# TODO any way around this? (if so, change fstab mount stanza to say "r"
			do_die chmod o+w "$REPO_/$2"

			# refresh mounts
			mount_refresh_ "$2"
			;;

		#	rem
		# Remove a repo entirely; whether archived or active
		rm|rem|del|delete)
			if ! repo_exists_ "$2"; then exit 1; fi

			# purge mounts
			repo purge_mounts $2
			# remove all mount dirs
			find /home -type d -name "$2" -exec rm -rf $V_ '{}' \; 2>/dev/null

			# remove repo (whether archived or not)
			rm -rf $V_ $REPO_/$2* # '*' so archived mounts list is removed also

			#remove group
			groupdel $V_ "git_$2" 2>/dev/null
			;;

		#	purge_mounts
		# unmount any bind-mounts pointing at repo, remove them from fstab
		purge_mounts)
			# unmount all instances of repo
			find /home -type d -name "$2" -exec umount -f $V_ '{}' 2>/dev/null \;
			# delete them from fstab
			sed -i"" -r '/^\S+'"$2"'\s/ d' /etc/fstab
			;;

		*)
			echo "Unknown command '$1'" >&2
			usage
			exit 1
			;;
	esac
	return 0
}


#	user()
#		$1	:	{ls|add|mod|rem}
#		$2	:	USER
user()
{
	# 	list
	# Show either active or inactive users
	if [[ "$1" == "ls" || "$1" == "list" ]]; then
		# handle '-v' flag by prepending the command to recreate
		if [[ $V_ ]]; then
			DUMP_="user add"
		fi
		# only go through "git-shell" users; user $2 as a filter string
		for u in $(getent passwd | grep "${2}.*git-shell" | cut -d ':' -f 1 | sort); do
			if [[ -e "/home/$u/$COND_" ]]; then
				echo "${DUMP_} $D_ $u"
			fi
		done | column -t
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
		add|mod)
			EXIST=$(getent passwd $2)
			# handle existing users gracefully
			if [[ $EXIST ]]; then
				if [[ ! $FORCE && ! $EXIST =~ git-shell ]]; then
					echo \
"User '$2' already exists but does not use git-shell, you may be clobbering an existing account.
Use '--force' to proceed despite this." >&2
					exit 1
				fi
				# ALWAYS force the shell, someone may have called
				#+	themselves "git-shell" LOL
				usermod -s /usr/bin/git-shell "$2" 2>/dev/null
			# add new users
			else
				adduser --shell /usr/bin/git-shell --disabled-password --gecos "" "$2" \
					| grep "Adding"
			fi

			# ensure there are no enabled git-shell commands
			rm -f $V_ "/home/$2/git-shell-commands"

			# Force proper SSH directory structure.
			do_die mkdir -p $V_ "/home/$2/.ssh"
			# Toggle user enable/disable state (if necessary)
			#+	by moving 'authorized_keys' file
			if [[ -e "/home/$2/$COND_OTHER_" ]]; then
				do_die mv $V_ "/home/$2/$COND_OTHER_" "/home/$2/$COND_"
			fi

			# always force file existing and update timestamp
			do_die touch /home/$2/$COND_
			# handle SSH directory permissions
			user_ssh_perms_ "$2"

			# if user should be enabled
			if [[ ! $D_ ]]; then
				# enable any commented-out mount entries for user
				sed -i"" -r 's|^#('"$REPO_BASE"'.*/home/'"$2"'.*)|\1|g' /etc/fstab
				sort -o /etc/fstab /etc/fstab
				# update mounts
				mount_refresh_ "$2"
			else
				# unmount repos
				user_umount_ "$2"
				# disable any mount entries for user
				sed -i"" -r 's|^([^#]+\s+/home/'"$2"'.*)|#\1|g' /etc/fstab
			fi
			;;

		#	rem
		# Remove a user entirely
		rm|rem|del|delete)
			# user must exist and be inactive/enabled according to '-i' flag
			if ! user_exists_ "$2"; then exit 1; fi

			# remove user
			do_die deluser "$2" | grep "Removing"

			# unmount repos
			user_umount_ "$2"
			# remove all mount entries
			sed -i"" -r '\|.*/home/'"$2"'.*| d' /etc/fstab \
				$REPO_/*.mounts $REPO_OTHER_/*.mounts 2>/dev/null

			# remove home dir
			do_die rm -rf $V_ "/home/$2"
			;;

		*)
			echo "Unknown command '$1'" >&2
			usage
			exit 1
			;;
	esac
	return 0
}


#	key()
#		$1	:	{ls|add|mod|rem}
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
				# handle '-v' flag by printing full command to recreate
				if [[ $V_ ]]; then
					sed -rn 's/.*(ssh-[rd]s[as].*)/'"key add $D_ $u "'\1/p' \
						/home/$u/$COND_
				else
					sed -rn 's/.*(ssh-[rd]s[as]) \S+(\S{24}) (\S+)$/'"$u"'\t\1 ...\2 \3/p' \
						/home/$u/$COND_
				fi
			fi
		done | column -t
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

	#because key may show up as multiple fields, or ONE quoted field :P
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
		add|mod)
			do_die echo "no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-user-rc $KEY_" \
				>> "/home/$USR_/$COND_"
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
	return 0
}


#	auth()
#		$1	:	{ls|add|mod|rem}
#		$2	:	USER
#		$3	:	REPO
auth()
{
	# 	list
	# Show either active or inactive authorizations, use $2 as a filter
	if [[ "$1" == "ls" || "$1" == "list" ]]; then
		# do we search fstab or the archived mounts lists?
		# INACTIVE is "#" when expecting disabled repos
		ARR=( $(sed -rn 's|^'"${INACTIVE_}$REPO_"'/(\S+)\s+/home/([^/]+).*|\1/\2|p' \
			/etc/fstab $REPO_/*.mounts 2>/dev/null \
			| grep "$2") )

		# handle '-v' flag by printing command stub
		if [[ $V_ ]]; then
			DUMP_="auth add"
		fi

		# print, marking write-enabled auths with 'w'
		for i in ${ARR[@]}; do
			# Apologies for making the delimiter '/', but it's the ONE character
			#+	I'm sure won't show up in either repo or user names.
			if getent group git_${i/%\/*/} | grep ${i/#*\//} >/dev/null; then
				W_="-w"
			else
				W_=""
			fi
			echo -e "${DUMP_} $D_ ${i/#*\//} $A_ ${i/%\/*/} $W_\n"
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
		add|mod)
			# add user to repo-specific group so they can write?
			if [[ $W_ ]]; then
				do_die usermod -s /usr/bin/git-shell -a -G "git_$3" "$2"
			# in case user COULD write previously, disable this
			else
				deluser "$2" "git_$3" 2>/dev/null
			fi

			# make sure a mountpoint exists for the bind mount
			do_die mkdir -p $V_ "/home/$2/$3"

			# if repo is active, manipulate fstab; else manipulate
			#+	the appropriate ".mounts" listing
			if [[ ! $A_ ]]; then
				FSTAB=/etc/fstab
			else
				FSTAB="$REPO_/${3}.mounts"
			fi
			# always insert
			echo -e "${INACTIVE_}$REPO_/$3\t/home/$2/$3\tnone\tbind,noexec,nobootwait\t0\t0" \
				>>"$FSTAB"
			# ... and de-dup afterwards
			sort -u -o "$FSTAB" "$FSTAB"
			# update mounts
			mount_refresh_ "$3"
			;;

		#	rem
		# Remove access to repo $3 for user $2
		rm|rem|del|delete)
			# unmount bind if mounted
			if mount | grep "/home/$2/$3" >/dev/null; then
				do_die umount -f $V_ "/home/$2/$3"
			fi

			# remove entry from fstab (whether commented out or not)
			sed -i"" -r '\|/home/'"$2/$3"'| d' /etc/fstab \
				$REPO_/*.mounts $REPO_OTHER_/*.mounts 2>/dev/null

			# remove user from group
			deluser "$2" "git_$3" 2>/dev/null
			;;

		*)
			echo "Unknown command '$1'" >&2
			usage
			exit 1
			;;
	esac
	return 0
}


#	dump()
#
# Dump a full backup
dump()
{
	bash -c "$0 repo ls -v" 2>/dev/null
	bash -c "$0 repo ls -v -a" 2>/dev/null
	bash -c "$0 user ls -v" 2>/dev/null
	bash -c "$0 key ls -v" 2>/dev/null
	bash -c "$0 user ls -v -d" 2>/dev/null
	bash -c "$0 key ls -v -d" 2>/dev/null
	bash -c "$0 auth ls -v" 2>/dev/null
	bash -c "$0 auth ls -v -d" 2>/dev/null
	bash -c "$0 auth ls -v -a" 2>/dev/null
	bash -c "$0 auth ls -v -d -a" 2>/dev/null
	return 0
}


#	sync()
#
#		$1	:	REMOTE_HOST
#
# Sync all repos with REMOTE_HOST
sync()
{
	# existentialism ... we may conceivably be run as:
	#+	git_sync$ sudo gsb.sh
	#+	admin$ sudo -u git_sync -H -- gsb.sh
	#+	admin$ sudo su -c gsb.sh
	# ... and in each case should work with:
	#+	git_sync
	#+	git_sync
	#+	admin
	U_=${SUDO_USER:-$USER}
	H_="/home/$U_"

	# sanity
	if [[ "$U_" == "root" ]]; then
		echo_die "root is never a valid gsb user"
	fi
	if [[ -z "$1" ]]; then
		echo_die "expecting REMOTE_HOST e.g. 'git.company.com' or '192.168.1.1'"
	fi
	if [[ ! -e "$H_/gsb/id_rsa" ]]; then
		echo_die "expecting a '$H_/gsb' directory containing 'id_dsa'"
	fi
	if ! which gitsync.sh; then
		echo_die "gitsync.sh not installed"
	fi
	# paranoia
	do_die chown -R $U_: "$H_/gsb"
	do_die chmod -R go-rwx "$H_/gsb"

	# set up ssh command
	cat >"$H_/gsb/ssh.sh" <<EOF
#!/bin/bash
# pass arguments to ssh when using git by pointing to this file in the GIT_SSH environment variable
ssh -o User=$U_ -o IdentityFile=$H_/gsb/id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \$*
EOF
	chmod +x "$H_/gsb/ssh.sh"
	export GIT_SSH="$H_/gsb/ssh.sh"

	# try to sync into all repos for which we have write-auth
	REPOS="$($0 auth ls | sed -rn 's/'$U_'\s+(\S+)\s+-w/\1/p')"
	FAILS=

	for r in $REPOS; do
		if ! gitsync.sh -b "$H_/$r" "ssh://$1/~/$r"; then
			FAILS="$FAILS\n$r"
		else
			echo $r
		fi
	done

	if [[ $FAILS ]]; then
		echo -e "failed syncs:\n$FAILS" >&2
		return 1
	else
		return 0
	fi
}


##########################################################
##			main				##
##########################################################

# generic flags
V_=
DUMP_=
FORCE_=
# 'repo' args
A_=
REPO_="/usr/src/git" # look at enabled repos
REPO_OTHER_="/usr/src/archive" # "other side" (aka: archived) repos here
QUOTA_=
# 'user' and 'key' args
D_=
INACTIVE_=
COND_=".ssh/authorized_keys" # active users have their keys here
COND_OTHER_=".ssh/disabled" # and the reciprocal is "inactive"
# 'auth' args
W_=
# parsing variables
MODE_=
MODE_ARGS_=()
while [[ "$1" ]]; do
	case $1 in
	##
	# flags
	##
	-h|-\?|--help)
		usage
		exit 0
		;;
	-v|--verbose)
		V_="-v" # do double-duty as a command flag ;)
		shift
		;;
	-a|--archived)
		A_="-a"
		REPO_="/usr/src/archive" # look at archived repos
		REPO_OTHER_="/usr/src/git" # "other side" (enabled) repos here
		shift
		;;
	-q|--quota)
		QUOTA_="$2"
		echo_die "quotas not yet implemented"
		shift; shift
		;;
	-d|--disabled)
		D_="-d"
		INACTIVE_='#' # do double-duty as a leading comment in /etc/fstab ;)
		COND_=".ssh/disabled" # users are expected to be disabled
		COND_OTHER_=".ssh/authorized_keys" # and the reciprocal is "enabled"
		shift
		;;
	-w|--write)
		W_="-w"
		shift
		;;
	-f|--force)
		FORCE_=1
		shift
		;;
	-?|--*)
		echo_die "option '$1' unknown"
		;;

	##
	# modes
	##
	repo|user|auth|key|dump|sync)
		MODE_=$1
		shift
		;;
	# possible mode arguments?
	# NOTE: each mode function sanitizes its arguments separately
	*)
		MODE_ARGS_=(${MODE_ARGS_[*]} $1)
		shift
		;;
	esac
done

# sanity check
check_platform

# bail if nothing to be done
if [[ ! $MODE_ ]]; then
	echo "nothing to do, possible options error?" >&2
	usage
	exit 1
# otherwise, exec the mode with all its arguments
else
	$MODE_ ${MODE_ARGS_[*]}
fi
