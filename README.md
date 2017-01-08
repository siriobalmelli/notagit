# git-shell_bind
A BASH script to administer GIT repos on a server, which are accessed via SSH only.

## Synopsis
TODO

## Example
TODO


## Architecture
A `repo` is a directory inside `/usr/src/git`, which is owned by `nobody` and a repo-specific system group.
The parent directory `/usr/src/git` is owned by root and not readable by others.

A `user` is a system user with public-key SSH access ONLY into a /usr/bin/git-shell,
	as well as some other security restrictions.

A user authorized to access a repo is:

-	added into the repo-specific group
-	has `/usr/src/[repo]` bind-mounted into `~/[repo]`

Read-only users are not added to the group, but only have the bind mount.


## Technical Motivation

-	Security
-	Simplicity
-	Use existing mechanisms only: no new (bug-prone) code


## TODO
- Quotas on .git repos (to stop users from crashing server)
- Possible to have a dedicated directory for .git temp files when read-only users
	are pulling?
- Pen testing


# pen test cases
Repos: A, B, C
User 1: rw repo A, r repo B
User 2: rw repo A (disabled)
User 3: rw all repos (key not given to pen tester)

## User 1
#. del repo A
#. w repo B
#. find repo C
#. r repo C
#. w repo C
#. crash system
#. find User 2

## User 2
#. log into system

## Anonymous assailant
#. crash system
#. snoop users
#. snoop traffic
