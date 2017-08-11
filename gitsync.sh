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
	echo -e "\n\nEXEC: $*"
	/bin/bash -c "$*"
	poop=$?
	if (( $poop )); then
		echo "failed: $*" >&2
		exit $poop
	fi
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
if ! git rev-parse --is-inside-work-tree; then
	echo "'$REPO_DIR' is not a git work tree" >&2
	exit 1
fi
STAT=( $(git status -bs) ) # a successful stat looks like: '## [LOCAL_BRANCH]'
if [[ ${#STAT[@]} != 2 ]]; then
	echo "git repo $(pwd) is dirty:" >&2
	git status >&2
fi
# don't checkout another branch - user may be working (!)
if [[ "${STAT[1]}" != "$LOCAL_BRANCH" ]]; then
	echo "branch ${STAT[1]} != requested $LOCAL_BRANCH" >&2
	exit 1
fi


# fetch remote
run_die git fetch "$REMOTE" "$REMOTE_BRANCH"
# Merge only if we are ahead (aka: merge will always work)
# This is taken from <https://github.com/simonthum/git-sync>,
#+	thank you to Simon Thum.
DIFF="$(git rev-list --count --left-right $remote_name/$branch_name...HEAD)"

case "$DIFF" in
	"") 		# no upstream
	    ;;
	"0	0")	# equal, no merge necessary
	    ;;
	"0	"*)
	    echo "ahead"
	    true
	    ;;
	*"	0")
	    echo "behind"
	    true
	    ;;
	*)
	    echo "diverged"
	    true
	    ;;
esac


# back to where we came from
popd
