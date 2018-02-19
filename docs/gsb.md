---
title: gsb
---

# gsb.sh

Manage a secure [Git](https://git-scm.com/) server which is accessed via
	[ssh](https://en.wikipedia.org/wiki/Secure_Shell):

-	repositories
-	users
-	user ssh keys
-	user authorizations to repositories

## Synopsis

```bash
usage:
gsb.sh [-v|--verbose] [-?|-h|--help]
	repo	{ls|add|mod|rm}	REPO		[-a|--archived] [-q|--quota <QUOTA>]
	user	{ls|add|mod|rm}	USER		[-d|--disabled]
	key		{ls|add|mod|rm}	USER KEY	[-d|--disabled]
	auth	{ls|add|mod|rm}	USER REPO	[-a|--archived] [-d|--disabled]	[-w|--write]
	dump

Field definition (RegEx):
REPO	:=	'[a-zA-Z_-]+'
USER	:=	'[a-zA-Z_-]+'
KEY		:=	'ssh-[rd]s[as] \S+ \S+' || {filename}

NOTES:
	- 'add' implies "create if not existing, modify if existing"
		and is synonymous with 'mod'.
	- script should be run with root privileges.
	- use '-v|--verbose' flag to pipe gsb.sh output back to input,
		e.g. to restore a backup or sync two systems
```

## Examples

Working with repos:

```bash
$ sudo gsb.sh repo ls
$
$ sudo gsb.sh repo add some_idea
/usr/src/git/some_idea ~/notagit
Initialized empty Git repository in /usr/src/git/some_idea/
Adding group 'git_some_idea' (GID 1003) ...
$
$ sudo gsb.sh repo ls
some_idea
$
```

Working with users and keys:

```bash
$ sudo gsb.sh user ls
$
$ sudo gsb.sh user add potter
Adding user 'potter' ...
Adding new group 'potter' (1004) ...
Adding new user 'potter' (1002) with group 'potter' ...
$
$ sudo gsb.sh user ls
potter
$
$ sudo gsb.sh key ls potter
potter
$
$ sudo gsb.sh key add potter /some/path/potter.pub
$
$ sudo gsb.sh key add potter ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDXZRpzaG4A0q6z3YPZbqaCZFcXtWztSz0za2ZmJejdH+bqdwDaQK7CLg+9ohNFKcUSue9GjgodcP0TXvvRq8ZNC6Po/DrV5OShT2znbwdRU/rL3ydsOJL5NQX4XOwXeQgx+NgugjtHVoBnYpiHhkuLazMcqOIhITKkBlllj+oi8NR74BQdsadhOOAzCy8UarFWMz86RC5U57QbehPVIxBdoa7CY76u8rTSuPXySdLS1PpIfiwNAVTXx7QwsrZWHvs3q8Wy3Q6qJDmGIhJXgT+R73Fej+XNWqzYxc0wIh26XvCYj9LOTOwL+IEaohfdXvBonfTwWQOd6bXs1YsEWp9D potter@hogwarts
$
$ sudo gsb.sh key ls potter
potter	ssh-rsa AAAAB3NzaC1yc2EAAAADAQAB... potter@somewhere
potter	ssh-rsa AAAAB3NzaC1yc2EAAAADAQAB... potter@hogwarts
$
```

Authorize a repo for a user:

```bash
$ sudo gsb.sh auth ls
$
$ sudo gsb.sh auth add potter some_idea
$
$ sudo gsb.sh auth ls
potter  some_idea
$
```

The above git repo can now be cloned (from Potter's machine):

```bash
git clone ssh://potter@[server]/~/some_idea
```

Authorization by default is read-only. Let's make it writeable:

```bash
$ sudo gsb.sh auth add -w potter some_idea
$
$ sudo gsb.sh auth ls
potter  some_idea  -w
```

To list repos, users and authorizations, use `ls` (which allows filtering):

```bash
$ sudo gsb.sh repo ls idea
some_idea
$
$ sudo gsb.sh user ls pott
potter
$
$ sudo gsb.sh auth ls "some_idea.*potter"
some_idea  potter
$
$ echo "gsb matches with RegEx, NOT globbing. A simple '*' won't work"
"gsb matches with RegEx, NOT globbing. A simple '*' won't work"
$
$ sudo gsb.sh auth ls "some_idea*potter"
$
```

Users can be disabled with the `-d` flag:

```bash
$ sudo gsb.sh user mod -d potter
$
$ sudo gsb.sh user ls potter
$
$ sudo gsb.sh user ls -d potter
-d  potter
$
$ sudo gsb.sh auth ls potter
$ sudo gsb.sh auth ls -d potter
-d  potter  some_idea  -w
$
```

Authorizations for disabled users are restored when they are re-enabled:

```bash
$ sudo gsb.sh user mod potter
$
$ sudo gsb.sh user ls
potter
$
```

Repos can be archived with the `-a` flag:

```bash
$ sudo gsb.sh repo mod -a some_idea
$
$ sudo gsb.sh repo ls
$
$ sudo gsb.sh repo ls -a
some_idea  -a
$
$ sudo gsb.sh auth ls potter
$
$ sudo gsb.sh auth ls potter -a
potter  -a  some_idea  -w
$
```

### Piping output back to input

`ls` commands run with the `-v` flag will produce output which is
	valid input for `gsb.sh`.

This means that piping output of `-v` into `gsb.sh` results in
	*no change of system state*.

```bash
$ sudo gsb.sh ls user
gitty
$ sudo gsb.sh ls user -v
user add gitty
$ sudo gsb.sh ls user -v | xargs -L 1 sudo gsb.sh
$
$ sudo gsb.sh ls user
gitty
$
```

The `dump` command is a convenient wrapper for multiple `ls -v` calls,
	in the order necessary to reproduce a complete system configuration.

Here is an example dump, excluding ssh key definitions for clarity.

```bash
$ sudo gsb.sh dump
repo  add  some_idea
repo  add  old_project  -a
user  add  potter
user  add  -d  luser
auth  add  potter  some_idea  -w
auth  add  -d  luser  some_idea
auth  add  -d  luser  -a  old_project
$
```

The output of `dump` piped to `xargs` will recreate the system state:

```bash
sudo gsb.sh dump |  xargs -L 1 sudo gsb.sh
```

Commands (or an entire dump) can be re-applied as many times as desired,
	system state remains consistent:

```bash
$ sudo gsb.sh dump >state.txt
$ cat state.txt | xargs -L 1 sudo gsb.sh
$ cat state.txt | xargs -L 1 sudo gsb.sh
$ sudo gsb.sh dump >state_b.txt
$ diff state.txt state_b.txt
$
```

`dump` can be repurposed to clean a system using command substitution:

```bash
$ sudo gsb.sh dump
repo  add  some_idea
repo  add  old_project  -a
user  add  potter
user  add  -d  luser
auth  add  potter  some_idea  -w
auth  add  -d  luser  some_idea
auth  add  -d  luser  -a  old_project
$
$ sudo gsb.sh dump | sed 's/ add / del /g' | xargs -L 1 sudo gsb.sh
Removing user 'potter' ...
Removing user 'luser' ...
user 'potter' doesn't exist or doesn't log into git-shell
user 'luser' doesn't exist or doesn't log into git-shell
user 'luser' doesn't exist or doesn't log into git-shell
$ sudo gsb.sh dump
$
```

## Architecture

A `repo` is a directory inside `/usr/src/git`, which is owned by `nobody`
	and a repo-specific system group.
The parent directory `/usr/src/git` is owned by root and not readable by others.

A `user` is a system user with public-key SSH access ONLY into a /usr/bin/git-shell,
	as well as some other security restrictions.

A user authorized to access a repo has
	`/usr/src/[repo]` bind-mounted into `~/[repo]`

A user authorized to write to a repo is also
	added to the repo-specific group.

## pen test scenario

-	Repos: A, B, C
-	User 1: rw repo A, r repo B
-	User 2: rw repo A (disabled)
-	User 3: rw all repos (key not given to pen tester)

### User 1

-	del repo A
-	w repo B
-	find repo C
-	r repo C
-	w repo C
-	crash system
-	find User 2, User 3

### User 2

-	log into system

### Anonymous assailant

-	crash system
-	snoop users
-	snoop traffic
