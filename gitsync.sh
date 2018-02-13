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
$0 [-v] -w	REPO_DIR LOCAL_BRANCH 	REMOTE REMOTE_BRANCH

$0 [-v] -b 	REPO_DIR		REMOTE

	-w	:	Working tree: sync LOCAL_BRANCH with REMOTE_BRANCH
	-b	:	Bare repo: sync all branches.
	-v	:	Print command output.
			Default behavior is to only print errors.
" >&2
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

#	bail()
# output an error message and exit non-0
#	$1	error message
bail()
{
	echo "$1" >&2
	exit 1
}


# system sanity
run_die which git >/dev/null

IS_BARE=""
IS_WORK=""
IS_VERBOSE=""

# getopts for -b REPO_DIR REMOTE
# Don't pass REPO_DIR and REMOTE as args to '-b'
while getopts ":wbv" opt; do
	case "$opt" in
		v)
			echo "verbose"
			IS_VERBOSE=1
			;;
		b)
			if [[ $IS_WORK ]]; then bail "more than one option specified"; fi
			IS_BARE=1
			;;
		w)
			if [[ $IS_BARE ]]; then bail "more than one option specified"; fi
			IS_WORK=1
			;;
		\?)
			echo "Invalid option: $OPTARG" >&2
			;;
	esac
done
# variable shift ... because arguments may have been passed e.g. as `-bv`
shift $((OPTIND - 1))

# no verbosity
if [[ -z $IS_VERBOSE ]]; then
	kill_stdout
fi


#	repo_sanity
# Common sanity checks for all repos
repo_sanity()
{
	# verify existence of directory
	if [[ ! -d "$REPO_DIR" ]]; then
		bail "'$REPO_DIR' is not a directory"
	fi
	pushd "$REPO_DIR"

	# Verify whether it's a git repo at all.
	if ! TYPE=$(git rev-parse --is-bare-repository); then
		bail "'$REPO_DIR' is not a git repo"
	fi
	# Verify that the repo type matches what we are doing
	if [[ $IS_BARE && $TYPE == 'false' ]]; then
		bail "$REPO_DIR not a bare repo"
	fi
}


##
#	working logic
##
if [[ $IS_BARE ]]; then
	REPO_DIR=$1
	REMOTE=$2
	repo_sanity
	run_die git fetch $REMOTE '*:*'
	# as the beatles say: fetch is all you need ;)
	exit 0

elif [[ $IS_WORK ]]; then
	REPO_DIR=$1
	LOCAL_BRANCH=$2
	REMOTE=$3
	REMOTE_BRANCH=$4
	repo_sanity
	# always be fetching
	run_die git fetch $REMOTE

else
	echo "no repo type (-w || -b) specified. nothing to do" >&2
	usage $0
	exit 1
fi


##
# from here down: handle working tree case
##
BRANCH=$(git branch | cut -d ' ' -f 2)
# bail if not in correct branch - user may be working!
if [[ "$BRANCH" != "$LOCAL_BRANCH" ]]; then
	bail "$REPO_DIR: branch $BRANCH != requested $LOCAL_BRANCH"
fi
# bail if uncommitted changes
STAT=$(git status -s)
if [[ $STAT ]]; then
	echo "git repo $(pwd) is dirty:" >&2
	git status >&2
	exit 1
fi

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
		run_die git merge "$REMOTE"/"$REMOTE_BRANCH"
		;;
	# anything else: trouble
	*)
		echo "$(pwd) : '$LOCAL_BRANCH' has diverged from $REMOTE/$REMOTE_BRANCH" >&2
		exit 1
		;;
esac
