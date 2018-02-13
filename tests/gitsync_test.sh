#!/bin/bash

set -e

# use adjacent directories instantiated as git repos to simulate:
#	bare_repo
#		- ahead
#		- behind
#		- diverged
#	working_tree
#		- ahead
#		- behind
#		- diverged
#		- unmerged changes

# init a bare repo with bare<$1> where
# $1 is number given as argument
init_bare()
{
	mkdir -p bare$1
	pushd bare$1
	git init --bare
	popd

	pushd ..
	pwd
	git clone tests/bare$1
	popd
}

# delete bare repo folders
rm_repos()
{
	rm -rf bare*
	rm -rf ../bare*
}

# commit a text file to repo
# '$1' repo number
# '$2' message to write to file
# '$3' commmit message
commit_to_repo()
{
	pushd ../bare$1
	echo $2 >> hello.txt
	git add .
	git commit -m "$3"
	git push
	popd
}

# sync repos
# '$1' repo to by synced into
# '$2' repo to be synced from
sync_repos()
{
	## how to catch failure before -e does?
	pushd ..
	./gitsync.sh -b tests/bare$1 ../bare$2 >&2
	pushd bare$1
	git pull
	popd
	popd
}

# Get into our own directory
pushd $(dirname "$0")


## AHEAD
echo "*************** AHEAD ******************************"
init_bare 1
commit_to_repo 1 "hello from bare1" "initial commit"
init_bare 2
sync_repos 2 1
commit_to_repo 2 "hello from bare2" "forward commit"
sync_repos 1 2
rm_repos

## BEHIND
echo "*************** BEHIND ******************************"
init_bare 1
commit_to_repo 1 "hello from bare1" "initial commit"
init_bare 2
sync_repos 2 1
rm_repos

## DIVERGE
echo "*************** DIVERGE ******************************"
init_bare 1
commit_to_repo 1 "hello from bare1" "initial commit"
init_bare 2
sync_repos 2 1
commit_to_repo 2 "hello from bare2" "divergent commit bare2"
commit_to_repo 1 "hello from bare1" "divergent commit bare1"
# expect failure
set +e
sync_repos 1 2
set -e
rm_repos



## WORKING TREE

# sync repos
# '$1' repo to by synced into
# '$2' local branch
# '$3' remote
# '$4' remote branch
sync_working_tree_repo()
{
	# ../gitsync.sh [-v] -w   REPO_DIR LOCAL_BRANCH   REMOTE REMOTE_BRANCH
	set -x
	pushd ..
	./gitsync.sh -w bare$1 $2 $3 $4
	git pull
	popd
}

# create a new remote
# '$1' remote url
# '$2' remote name
# '$3' git repo dir
git_remote_add()
{
	pushd $3
	git remote add $2 $1
#	git pull $2 master
	popd
}




## BEHIND

echo "*************** WT BEHIND ******************************"
init_bare 1
commit_to_repo 1 "hello from repo1" "initial commit"
init_bare 2
# make bare2 equal to bare1
sync_repos 2 1

# add remote bare1 into bare2
git_remote_add ../bare1 bare1 ../bare2
# set bare1 ahead of current repo (bare2)
commit_to_repo 1 "hello from 1 again" "second commit"

# sync bare2 which is BEHIND remote (bare1)
sync_working_tree_repo 2 master bare1 master

rm_repos

## AHEAD

echo "*************** WT AHEAD ******************************"
init_bare 1
commit_to_repo 1 "hello from repo1" "initial commit"
init_bare 2
# make bare2 equal to bare1
sync_repos 2 1

# add remote bare1 into bare2
git_remote_add ../bare1 bare1 ../bare2
# set current repo (bare2) ahead of bare1 (remote)
#commit_to_repo 2 "hello from 2" "second commit"

# sync bare2 which is AHEAD of remote (bare1)
echo "**************** SYNC *********************************"
sync_working_tree_repo 2 master bare1 master

rm_repos

## DIVERGE

#echo "*************** WT DIVERGE ******************************"
init_bare 1
commit_to_repo 1 "hello from repo1" "initial commit"
init_bare 2
commit_to_repo 2 "hello from repo2" "initial commit"

git_remote_add ../bare1 bare1 ../bare2
commit_to_repo 1 "hello from 1 again" "second commit"

commit_to_repo 2 "divergent commit" "diverged"

## We expect a barf about divergent commits
## ignore this
set +e
sync_working_tree_repo 2 master bare1 master
set -e

rm_repos
popd # leave directory again
exit 0
