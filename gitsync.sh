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
$0 [repo_dir] [local_branch] [remote] [remote_branch]" >&2
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


# system sanity
run_die which git

# arguments
if [[ $# != 4 ]]; then
	usage $0
	exit 1
fi

REPO_DIR=$1
LOCAL_BRANCH=$2
REMOTE=$3
REMOTE_BRANCH=$4


# sanity check local repo
run_die pushd "$REPO_DIR"
if ! git rev-parse --is-inside-work-tree >/dev/null; then
	echo "'$REPO_DIR' is not a git work tree" >&2
	exit 1
fi
# bail if not in correct branch - user may be working!
BRANCH=$(git branch | cut -d ' ' -f 2)
if [[ "$BRANCH" != "$LOCAL_BRANCH" ]]; then
	echo "branch $BRANCH != requested $LOCAL_BRANCH" >&2
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
	# no upstream
	"")	;;
	# equal or ahead: no merge necessary
	"0"*)	;;
	# behind: merge
	# don't rebase, merge: user may have 'post-merge' githooks
	*[^0-9]"0")
		run_die git merge "$REMOTE" "$REMOTE_BRANCH"
		;;
	# anything else: trouble
	*)
		echo "$REPO_DIR : branch $LOCAL_BRANCH has diverged from $REMOTE/$REMOTE_BRANCH" >&2
		exit 1
		;;
esac
