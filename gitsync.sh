#!/bin/bash
#
#	gitsync
#
# Synchronize a git repository safely (safe to call from e.g. cron)

#	usage()
# Print usage to stderr
#		$0	:	command name
usage()
{
	echo -e "usage:
$0 [-v] REPO_DIR LOCAL_BRANCH REMOTE REMOTE_BRANCH
	-v	:	verbose: Print command output.
			Default behavior is to only print errors.
$0 [-v] -b REPO_DIR REMOTE" >&2
}

#	run_die()
# Simple helper: exec something with the shell; die if it barfs
#		$*	:	command sequence
run_die()
{
	echo -e "EXEC: $*"
	/bin/bash -c "$*"
	poop=$?
	if (( $poop )); then
		echo "failed: $*" >&2
		exit $poop
	fi
	echo
}

#	kill_stdout()
# standard behavior: close stdout for rest of script
kill_stdout()
{
	exec 1>/dev/null
	echo "should NOT print"
}

# system sanity
run_die which git >/dev/null

IS_BARE=false
IS_VERBOSE=false

# getopts for -b REPO_DIR REMOTE
# Don't pass REPO_DIR and REMOTE as args to '-b'
while getopts ":bv" opt; do
	case "$opt" in
		v)
			echo "verbose"
			IS_VERBOSE=true
			;;
		b)
			IS_BARE=true
			;;
		\?)
			echo "Invalid option: $OPTARG" >&2
			;;
	esac
done

# no verbosity
if [[ $IS_VERBOSE == false ]]; then
	kill_stdout
# verbosity but is a working tree, so only '-v' flag
elif [[ $IS_BARE == false && $IS_VERBOSE == true ]];  then
	shift
fi

REPO_DIR=$1
LOCAL_BRANCH=$2
REMOTE=$3
REMOTE_BRANCH=$4

# If its a bare repo to sync, reset the variables correctly
if [[ $IS_BARE == true ]]; then
	# 4 args means we have '-v -b' flags
	if [[ $# == 4 ]]; then
		shift
		shift
	else
	# 3 args means a '-vb' flag
		shift
	fi
	REPO_DIR=$1
	REMOTE=$2
fi

# verify existence of directory
if [[ ! -d "$REPO_DIR" ]]; then
	echo "'$REPO_DIR' is not a directory" >&2
	exit 1
fi
pushd "$REPO_DIR"

# Verify whether it's a git repo at all.
if ! TYPE=$(git rev-parse --is-bare-repository); then
	echo "'$REPO_DIR' is not a git repo" >&2
	exit 1
fi

##
# handle bare repo differently
##
if [[ $IS_BARE == true && $TYPE == 'true' ]]; then
	# git fetch all branches into the current bare repo
	run_die git fetch $REMOTE '*:*'
	exit 0
elif [[ $IS_BARE == false && $TYPE == 'true' ]]; then
	echo "Not valid for a bare repo, only run on working tree"
	usage $0
        exit 0
fi


##
# handle working tree
##
# bail if not in correct branch - user may be working!
BRANCH=$(git branch | cut -d ' ' -f 2)
if [[ "$BRANCH" != "$LOCAL_BRANCH" ]]; then
	echo "$REPO_DIR: branch $BRANCH != requested $LOCAL_BRANCH" >&2
	exit 1
fi
# bail if uncommitted changes
STAT=$(git status -s)
if [[ $STAT ]]; then
	echo "git repo $(pwd) is dirty:" >&2
	git status >&2
	exit 1
fi


# fetch remote
run_die git fetch "$REMOTE" "$REMOTE_BRANCH"
# Merge only if we are BEHIND remote (aka: merge will always work)
# This is inspired by <https://github.com/simonthum/git-sync>,
#+	thank you Simon Thum.
DIFF="$(git rev-list --count --left-right $REMOTE/$REMOTE_BRANCH...$LOCAL_BRANCH)"

# crummy globbing to avoid any tab-vs-space weirdness between systems
case "$DIFF" in
	"")
		echo "no upstream" >&2
		;;
	"0"*)
		echo "$(pwd) : '$LOCAL_BRANCH' equal or ahead of $REMOTE/$REMOTE_BRANCH"
		;;
	# behind: merge
	# don't rebase, merge: user may have 'post-merge' githooks
	*[^0-9]"0")
		run_die git merge "$REMOTE" "$REMOTE_BRANCH"
		;;
	# anything else: trouble
	*)
		echo "$(pwd) : '$LOCAL_BRANCH' has diverged from $REMOTE/$REMOTE_BRANCH" >&2
		exit 1
		;;
esac
