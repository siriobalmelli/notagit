#!/bin/bash

usage()
{
	echo -e "usage:
$0 [-v|--verbose] [-i|--inactive]
	[-q|--quota MB]				repo {ls|add|disable|rm} REPO
	[-s|--ssh-key KEY] [-k|--key-file FILE]	user {ls|add|disable|rm} USER
	[-w|--write]				auth {ls|add|rm} USER REPO

NOTES:
	- script should be run with root privileges.
	- KEY should be quoted.
	- space characters in repo names are a very bad idea
" >&2
}


# static assumptions
REPO_BASE="/usr/src/git"	# active repos go here
ARCH_BASE="/usr/src/archive"	# disabled repos go here


# get arguments
QUOTA_=
KEY_=
WRITE_=
DBG_=
INACTIVE_=
while [[ "$1" \
	&& "$1" != "repo" \
	&& "$1" != "user" \
	&& "$1" != "auth" ]]
do
	case $1 in
	-v|--verbose)
		DBG_="-v" # do double-duty as a command flag ;)
		DEBUG_PRN_="debugging enabled:	$*"
		shift
		;;
	-i|--inactive)
		INACTIVE_=1
		shift
		;;
	-q|--quota)
		DEBUG_PRN_="got quota of $2"
		QUOTA_="$2"
		echo "quotas not yet implemented" >&2
		exit 1
		shift; shift
		;;
	-s|--ssh-key)
		DEBUG_PRN_="got key: $2"
		KEY_="$2"
		shift; shift
		;;
	-k|--key_file)
		if [[ ! -e "$2" ]]; then
			echo "key file '$2' doesn't exist" >&2
			exit 1
		fi
		KEY_="$(cat $2)"
		DEBUG_PRN_="got key from file: $KEY_"
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


#	repo()
#
#		$1	:	{ls|add|archive|exhume}
#		$2	:	REPO
#
# TODO implement quotas
repo()
{
	# all invocations reqire a command
	if [[ ! "$1" ]]; then
		usage
		exit 1
	fi

	# 	list
	# Show either active or inactive repos, user $2 as a filter string
	if [[ "$1" == "ls" || "$1" == "list" ]]; then
		if [[ ! $INACTIVE_ ]]; then
			ls -1 "$REPO_BASE" | grep "$2"
			return $?
		else
			ls -1 --ignore="*.mounts" "$ARCH_BASE" | grep "$2"
			return $?
		fi
	fi

	# all other invocations besides "list" require a repo name
	if [[ ! "$2" ]]; then
		echo "repo() expects: $1 REPO" >&2
		usage
		exit 1
	fi
	# remove all spaces from repo
	R_=$(echo "$2" | sed 's/ /_/g')

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
			if [[ ! -d "$REPO_BASE/$R_" ]]; then

				# if it exists but is disabled, move it back
				if [[ -d "$ARCH_BASE/$R_" ]]; then
					mv $DBG_ "$ARCH_BASE/$R_" "$REPO_BASE/$R_"
					poop=$?; if (( $poop )); then exit $poop; fi
					# restore fstab entries for repo
					cat "$ARCH_BASE/${R_}.mounts" >>/etc/fstab
					rm -f $DBG_ "$ARCH_BASE/${R_}.mounts"
					sort -o /etc/fstab /etc/fstab

				# no? create it
				else
					mkdir $DBG_ "$REPO_BASE/$R_"
					poop=$?; if (( $poop )); then exit $poop; fi
					pushd "$REPO_BASE/$R_"
					git init --bare
					poop=$?; if (( $poop )); then popd; rm -rf "$REPO_BASE/$R_"; exit $poop; fi
				fi
			fi

			# make sure repo-specific group exists
			if ! getent group | grep "git_$R_$" >/dev/null; then
				addgroup "git_$R_"
					poop=$?; if (( $poop )); then exit $poop; fi
			fi

			# force ownership and permissions on repo dir
			chown -R nobody:"git_$R_" "$REPO_BASE/$R_"
				poop=$?; if (( $poop )); then exit $poop; fi
			chmod -R u=rwX,g=rwXs,o=rX,o-w "$REPO_BASE/$R_" # notice group sticky bit
				poop=$?; if (( $poop )); then exit $poop; fi
			# This is to allow git to write temporary account stuff
			#+	when a read-only user pulls
			# TODO any way around this? (if so, change fstab mount stanza to say "r"
			chmod o+w "$REPO_BASE/$R_"
				poop=$?; if (( $poop )); then exit $poop; fi

			# refresh mounts
			mount -a $DBG_
			;;

		#	disable
		# Archive an existing repo; disable access by users but save
		#+	their ~/[repo] mountpoints intact for later restoration.
		# NOTE that some mountpoints may have been DISABLED, we need to preserve this.
		dis|disable)
			# verify repo exists in the first place
			if [[ ! -d "$REPO_BASE/$R_" ]]; then
				echo "Repo '$R_' doesn't exist. Cannot archive" >&2
				exit 1
			fi

			# verify no archived project by the same name
			if [[ -d "$ARCH_BASE/$R_" ]]; then
				echo "Archived repo '$R_' already exists." >&2
				exit 1
			fi

			# preserve mount entries from fstab
			sed -rn '\|'"$REPO_BASE/$R_"'| p' /etc/fstab >"$ARCH_BASE/${R_}.mounts"
			# recurse: purge mounts
			repo purge_mounts $R_

			# move repo to archive
			mv $DBG_ "$REPO_BASE/$R_" "$ARCH_BASE/$R_"
				poop=$?; if (( $poop )); then exit $poop; fi
			;;

		#	rem
		# Remove a repo entirely; whether archived or active
		rm|rem|del|delete)
			# purge mounts
			repo purge_mounts $R_
			# remove all mount dirs
			find /home -type d -name "$R_" -exec rm -rf $DBG_ '{}' \; 2>/dev/null

			# remove repo and/or archive dir, archived mounts list
			rm -rf $DBG_ "$REPO_BASE/$R_" "$ARCH_BASE/${R_}*"

			#remove group
			groupdel "git_$R_"
				poop=$?; if (( $poop )); then exit $poop; fi
			;;

		#	purge_mounts
		# unmount any bind-mounts pointing at repo, remove them from fstab
		purge_mounts)
			# unmount all instances of repo
			find /home -type d -name "$R_" -exec umount -f $DBG_ '{}' 2>/dev/null \;
			# delete them, and empty lines, too
			sed -i"" -re '\|'"$REPO_BASE/$R_"'| d' -e '/^\s*$/ d' /etc/fstab
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
	# all calls require command
	if [[ ! "$1" ]]; then
		usage
		exit 1
	fi

	# 	list
	# Show either active or inactive users
	if [[ "$1" == "ls" || "$1" == "list" ]]; then
		# disabled users have '.ssh/disabled'
		if [[ $INACTIVE_ ]]; then
			COND_=".ssh/disabled"
		# active ones have 'authorized_keys' instead
		else
			COND_=".ssh/authorized_keys"
		fi
		# only go through "git-shell" users; user $2 as a filter string
		for u in $(getent passwd | grep "${2}.*git-shell" | cut -d ':' -f 1 | sort); do
			if [[ -e "/home/$u/$COND_" ]]; then
				echo $u
			fi
		done
		#done
		return 0
	fi

	# all other commands require USER
	if [[ ! "$2" ]]; then
		usage
		exit 1
	fi

	case $1 in
		#	add
		# Add a new user; Enable a previously disabled user; Validate a user.
		# An active user can ONLY log in via SSH, to a git-shell.
		new|add|en|enable)
			# if no user, create
			if ! getent passwd | grep $2 >/dev/null; then
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
	
			# optional: add key entry
			if [[ "$KEY_" ]]; then
				echo "no-port-forwarding,no-agent-forwarding,no-X11-forwarding,no-user-rc $KEY_" \
					>> "/home/$2/.ssh/authorized_keys"
				poop=$?; if (( $poop )); then exit $poop; fi
				# sort and de-dup keys
				sort -u -o "/home/$2/.ssh/authorized_keys" "/home/$2/.ssh/authorized_keys"
			# if not at least timestamp 'authorized_keys'
			else
				touch "/home/$2/.ssh/authorized_keys"
				poop=$?; if (( $poop )); then exit $poop; fi
			fi

			# force ownership and permissions
			chown $DBG_ -R "$2": "/home/$2/.ssh"
			chmod $DBG_ -R ugo-rwx,u+rX "/home/$2/.ssh"

			# enable any commented-out mount entries for user
			sed -i"" -r 's|^#('"$REPO_BASE"'.*/home/'"$2"'.*)|\1|g' /etc/fstab
			# update mounts
			mount -a $DBG_
			;;

		#	disable
		# To disable a user, rename their authorized_keys file
		dis|disable)
			# user must exist
			if ! getent passwd | grep $2 >/dev/null; then
				echo "Cannot find user '$2' to be disabled" >&2
				exit 1
			fi

			# rename authorized_keys file
			if [[ -e "/home/$2/.ssh/authorized_keys" ]]; then
				mv "/home/$2/.ssh/authorized_keys" "/home/$2/.ssh/disabled"
				poop=$?; if (( $poop )); then exit $poop; fi
			fi

			# unmount repos (recurse)
			user umount "$2"
			# disable any mount entries for user
			sed -i"" -r 's|^('"$REPO_BASE"'.*/home/'"$2"'.*)|#\1|g' /etc/fstab
			;;

		#	rem
		# Remove a user entirely
		rm|rem|del|delete)
			# user must exist
			if ! getent passwd | grep $2 >/dev/null; then
				echo "Cannot find user '$2' to be removed" >&2
				exit 1
			fi
			# remove user
			deluser "$2"
				poop=$?; if (( $poop )); then exit $poop; fi

			# unmount repos (recurse)
			user umount "$2"
			# remove all mount entries
			sed -i"" -r '\|.*'"/home/$2"'.*| d' /etc/fstab

			# remove home dir
			rm -rf $DBG_ "/home/$2"
				poop=$?; if (( $poop )); then exit $poop; fi
			;;

		#	umount
		# unmount any mounted repos for USER
		umount)
			mount | grep "/home/$2" | cut -d ' ' -f 3 | xargs -I{} umount -f $DBG_ {}
			;;
		
		*)
			echo "Unknown command '$1'" >&2
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
	# must at least have a command
	if [[ ! "$1" ]]; then
		usage
		exit 1
	fi

	# 	list
	# Show either active or inactive authorizations, user $2 as a filter
	if [[ "$1" == "ls" || "$1" == "list" ]]; then
		if [[ ! $INACTIVE_ ]]; then
			sed -rn 's|^\s*'"$REPO_BASE"'/(\S+)\s+/home/([^/]+).*|\1  \2|p' /etc/fstab | grep "$2"
		else
			sed -rn 's|^\s*#\s*'"$REPO_BASE"'/(\S+)\s+/home/([^/]+).*|\1  \2|p' /etc/fstab | grep "$2"
		fi
		return 0
	fi

	# all other calls must give USER and REPO
	if [[ ! "$2" || ! "$3" ]]; then
		echo "auth() expects: $1 USER REPO" >&2
		usage
		exit 1
	fi

	# user must exist and must have the proper shell
	if ! getent passwd | grep "$2.*git-shell" >/dev/null; then
		echo "user '$2' doesn't exist or doesn't log into git-shell" >&2
		exit 1
	fi
	# user must not be disabled
	if [[ -e "/home/$2/.ssh/disabled" ]]; then
		echo "user '$2' is disabled" >&2
		exit 1
	fi

	# remove all spaces from repo
	R_=$(echo "$3" | sed 's/ /_/g')
	# repo must exist
	if [[ ! -d "$REPO_BASE/$3" ]]; then
		echo "repo '$3' doesn't exist" >&2
		exit 1
	fi

	case $1 in
		#	add
		# Allow/verify that user $2 can access repo $R_
		new|add|en|enable)
			# add user to repo-specific group so they can write?
			if [[ $WRITE_ ]]; then
				usermod -s /usr/bin/git-shell -a -G "git_$R_" "$2"
				poop=$?; if (( $poop )); then exit $poop; fi
			# in case user COULD write previosly, disable this
			else
				deluser "$2" "git_$R_" 2>/dev/null
			fi

			# make sure a mountpoint exists for the bind mount
			mkdir -p $DBG_ "/home/$2/$R_"
				poop=$?; if (( $poop )); then exit $poop; fi
			# make sure fstab entry exists for bind mount, 
			#+	use 'while' to ensure its printed either way
			while ! grep -E "/home/$2/$R_" /etc/fstab; do
				printf "$REPO_BASE/$R_\t/home/$2/$R_\tnone\tbind,noexec\t0\t0" >>/etc/fstab
				sort -o /etc/fstab /etc/fstab
			done
			# update mounts
			mount -a $DBG_
				poop=$?; if (( $poop )); then exit $poop; fi
			;;

		#	rem
		# Remove access to repo $R_ for user $2
		rm|rem|del|delete)
			# unmount bind if mounted
			if mount | grep "/home/$2/$R_" >/dev/null; then
				umount -f $DBG_ "/home/$2/$R_"
				poop=$?; if (( $poop )); then exit $poop; fi
			fi

			# remove entry from fstab
			sed -i"" -r '\|/home/'"$2/$R_"'| d' /etc/fstab

			# remove user from group
			deluser "$2" "git_$R_"
			;;

		*)
			echo "Unknown command '$1'" >&2
			usage
			exit 1
			;;
	esac
}


##
# 	main
##
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
*)
	echo "Unknown command '$1'" >&2
	usage
	exit 1
	;;
esac
