# git-shell_bind
A BASH script to administer GIT repos on a server, which are accessed via SSH only.

## Installation
`gsb.sh` can be run from this directory, where is was downloaded.

On a production server, it probably belongs in `/usr/sbin`.
To put it there, you can run `sudo make install`.

## Synopsis
```{.bash}
usage:
./gsb.sh [-v|--verbose] [-i|--inactive]
	[-q|--quota MB]					repo {ls|add|disable|rm} REPO
	[-s|--ssh-key KEY] [-k|--key-file FILE]		user {ls|add|disable|rm} USER
	[-r|--read-only]				auth {ls|add|rm} USER REPO

NOTES:
	- script should be run with root privileges.
	- KEY should be quoted.
	- space characters in repo names are a very bad idea
```

## Examples

Create new repo "some_idea", create a new user "potter" and give them RW access to it,
	then change your mind and give them read-only access:
```{.bash}
# gsb.sh repo add some_idea
/usr/src/git/some_idea /home/ubuntu/git-shell_bind
Initialized empty Git repository in /usr/src/git/some_idea/
Adding group `git_some_idea' (GID 1014) ...
Done.
#
# gsb.sh -k ./id_rsa_potter.pub user add potter
Adding user `potter' ...
Adding new group `potter' (1027) ...
Adding new user `potter' (1007) with group `potter' ...
Creating home directory `/home/potter' ...
Copying files from `/etc/skel' ...
#
# gsb.sh -w auth add potter some_idea
/usr/src/git/some_idea	/home/potter/some_idea	none	bind,noexec	0	0
#
# gsb.sh auth add potter some_idea
Removing user `potter' from group `git_some_idea' ...
Done.
/usr/src/git/some_idea	/home/potter/some_idea	none	bind,noexec	0	0
#
```

This repo can now be cloned by the owner of the corresponding private key with:
``` {.bash}
git clone ssh://potter@[server]/~/some_idea
```

To list active repos, users and authorizations, use `ls` (which allows filtering):
```{/bash}
# gsb.sh repo ls
some_idea
#
# gsb.sh user ls
potter
#
# gsb.sh auth ls some_idea
some_idea  potter
#
```

That last gets only the authorizations for `some_idea`.

Repos and users can be disabled, after which they will show up when the `-i`
	flag is used on `ls`:
```{.bash}
# gsb.sh user disable potter
#
# gsb.sh user ls potter
#
# gsb.sh -i user ls potter
potter
#
# gsb.sh auth ls potter
# gsb.sh -i auth ls potter
some_idea  potter
#
```

NOTE that an `auth` CANNOT be disabled; it can only be added or removed.
However, when a `user` or `repo` is disabled, all of their authorizations are saved,
	and restored when the user is once again enabled:
```{.bash}
# gsb.sh user add potter
#
# gsb.sh -i auth ls potter
#
# gsb.sh auth ls potter
some_idea  potter
#
```


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
-	del repo A
-	w repo B
-	find repo C
-	r repo C
-	w repo C
-	crash system
-	find User 2, User 3

## User 2
-	log into system

## Anonymous assailant
-	crash system
-	snoop users
-	snoop traffic
