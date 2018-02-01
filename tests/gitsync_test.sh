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

exit 0
