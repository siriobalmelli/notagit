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
./gsb.sh [-v|--verbose] [-i|--inactive]
[-q|--quota MB]   repo	{ls|add|disable|rm}	REPO
                  user	{ls|add|disable|rm}	USER
                  key	{ls|add|rm}		USER KEY
[-w|--write]      auth	{ls|add|rm}		USER REPO
                  dump

Field definition (RegEx):
REPO	:=	'[a-zA-Z_-]+'
USER	:=	'[a-zA-Z_-]+'
KEY	:=	'ssh-[rd]s[as] \S+ \S+' || {filename}

NOTES:
	- script should be run with root privileges.
	- KEY must be quoted (or must be a file)
	- quotas not implemented yet
	- use 'dump|verbose' flag to pipe $0 output back to input,
		e.g. to restore a backup or sync two systems
```

## Examples

Working with repos:

```bash
$ sudo gsb.sh repo ls
$
$ sudo gsb.sh repo add some_idea
/usr/src/git/some_idea ~/github_repos/git-shell_bind
Initialized empty Git repository in /usr/src/git/some_idea/
Adding group `git_some_idea' (GID 1044) ...
Done.
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
Adding user `potter' ...
Adding new group `potter' (1043) ...
Adding new user `potter' (1007) with group `potter' ...
Creating home directory `/home/potter' ...
Copying files from `/etc/skel' ...
$
$ sudo gsb.sh user ls
potter
$
$ sudo gsb.sh key ls potter
potter
$
$ sudo gsb.sh key add potter /some/path/potter.pub
$
$ sudo bash -x gsb.sh key add potter ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDXZRpzaG4A0q6z3YPZbqaCZFcXtWztSz0za2ZmJejdH+bqdwDaQK7CLg+9ohNFKcUSue9GjgodcP0TXvvRq8ZNC6Po/DrV5OShT2znbwdRU/rL3ydsOJL5NQX4XOwXeQgx+NgugjtHVoBnYpiHhkuLazMcqOIhITKkBlllj+oi8NR74BQdsadhOOAzCy8UarFWMz86RC5U57QbehPVIxBdoa7CY76u8rTSuPXySdLS1PpIfiwNAVTXx7QwsrZWHvs3q8Wy3Q6qJDmGIhJXgT+R73Fej+XNWqzYxc0wIh26XvCYj9LOTOwL+IEaohfdXvBonfTwWQOd6bXs1YsEWp9D potter@hogwarts
$
$ sudo gsb.sh key ls potter
potter	ssh-rsa AAAAB3NzaC1yc2EAAAADAQAB... potter@somewhere
potter	ssh-rsa AAAAB3NzaC1yc2EAAAADAQAB... potter@hogwarts
$
```

Authorize a repo for a user:

```bash
$ sudo gsb.sh auth add potter some_idea
/usr/src/git/some_idea	/home/potter/some_idea	none	bind,noexec	0	0
$
$ echo "whoops, that was read-only. let's make it writeable"
"whoops, that was read-only. let's make it writeable"
$
$ sudo gsb.sh auth add -w potter some_idea
/usr/src/git/some_idea	/home/potter/some_idea	none	bind,noexec	0	0
$
```

The above git repo can now be cloned (from Potter's machine):

```bash
git clone ssh://potter@[server]/~/some_idea
```

To list active repos, users and authorizations, use `ls` (which allows filtering):

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

Repos and users can be disabled, after which they will show up when the `-i`
	flag is used on `ls`:

```bash
$ sudo gsb.sh user disable potter
$
$ sudo gsb.sh user ls potter
$
$ sudo gsb.sh -i user ls potter
potter
$
$ sudo gsb.sh auth ls potter
$ sudo gsb.sh -i auth ls potter
some_idea  potter
$
```

NOTE that an `auth` CANNOT be disabled; it can only be added or removed.
However, when a `user` or `repo` is disabled, all of their authorizations are saved,
	and restored when the `user` or `repo` is once again enabled:

```bash
$ sudo gsb.sh user add potter
$
$ sudo gsb.sh -i auth ls potter
$
$ sudo gsb.sh auth ls potter
some_idea  potter
$
```

### dumping and restoring

All `ls` commands run with the `-v` or `--dump` flag are designed
	to produce output which is suitable input for an invocation of
	`gsb.sh`:

```bash
$ sudo gsb.sh ls user
gitty
$ sudo gsb.sh ls user -v
user add gitty
$ sudo gsb.sh ls user -v | xargs -L 1 sudo ./gsb.sh
$
$ sudo gsb.sh ls user
gitty
$
```

The `dump` command is simply a wrapper for multiple `ls -v` calls,
	in the order necessary to reproduce a system configuration:

```bash
$ sudo ./gsb.sh dump
repo add hi
repo add third
repo disable hello
user add gitty
key add gitty ssh-dss AAAAB3NzaC1kc3MAAACBAMS9UJWg59QOSgYIJ+Et0/URoF6lIavUmCAJrQC0CO2IbaaV+F5BPkV4EH7YR5jxXxA2r+AVs5ZA/u9JkhQ8L1oDP/P+Zgwv4IDByoZ5ExKMBKg2Y9TmtzRA3ahvEvJJNPUS4Ft50vpj7i3bktY5PjceqrH4jI7amsMMmnqyKy5BAAAAFQDrBuiwuUpSxcBZBTYTvJaJH7MkLwAAAIBX8ORtNuvmraoVEUgwp+GFlo/ql28yVM1KfT1WKZdUnzUvVloTPdTDflxxvjqwM8zaXNhaspAQO7bCBGHV6Cgq0QTjEi8voSQyAG4m+PGtzmGPL5tovmm3VwEZgU68Ya3JAVFHy3AFxE4sfiW4XLcy1YJ77JEdCgAqfPtn+r6PEgAAAIEAqt6kHkR+ArcJCo03CMx/O0gQh93pl/V6nbTbNOKVCUlMAPuvqXttkwuw/kUdywgMeR4M6RKfjOSvpiJ/F4sd5x8Lyelh6qQWcUCZ2GbFgj1pHZJ5MwUykmFZJZV3y2aGkLfpwakXuqSJpxqGI89ydFi/QyB0W4sokgSUBUI3VKQ= gitty@work.tv
key add gitty ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDH3J9WSuqjiwubbB0+RMaq5tULH496S5w+6uRGItuO+JYfIYt+TZ8+acc+DeYj5rjif+EZaLOJqJ8wQhrYkDJoHGcpZA8MHVZ7yOfslqVBn3+KuZvej7qowvVK2j1C+mO1LIOLFetYUd878J8mLBObMLjAhVF+zryGix+sn8gdlridMkCf8GQEs2giCi6MsURoWes6Ot+3Ok5NHEBH5vhhq08yEaoUQRoDrHBGKx1oRAi+SFkw0Y66AQGWVOoi6xOApk5CtsOCvL1ViJkCQk1kPM4GqftwbmejOH/MXaUd/rfEBRsyhS0GDWICdfL5ezYlMBsUqxKyTuTYlsoNcO9b gitty@yarn.com
user disable gitster
user disable yoyoyo
key add -i gitster ssh-dss AAAAB3NzaC1kc3MAAACBAMS9UJWg59QOSgYIJ+Et0/URoF6lIavUmCAJrQC0CO2IbaaV+F5BPkV4EH7YR5jxXxA2r+AVs5ZA/u9JkhQ8L1oDP/P+Zgwv4IDByoZ5ExKMBKg2Y9TmtzRA3ahvEvJJNPUS4Ft50vpj7i3bktY5PjceqrH4jI7amsMMmnqyKy5BAAAAFQDrBuiwuUpSxcBZBTYTvJaJH7MkLwAAAIBX8ORtNuvmraoVEUgwp+GFlo/ql28yVM1KfT1WKZdUnzUvVloTPdTDflxxvjqwM8zaXNhaspAQO7bCBGHV6Cgq0QTjEi8voSQyAG4m+PGtzmGPL5tovmm3VwEZgU68Ya3JAVFHy3AFxE4sfiW4XLcy1YJ77JEdCgAqfPtn+r6PEgAAAIEAqt6kHkR+ArcJCo03CMx/O0gQh93pl/V6nbTbNOKVCUlMAPuvqXttkwuw/kUdywgMeR4M6RKfjOSvpiJ/F4sd5x8Lyelh6qQWcUCZ2GbFgj1pHZJ5MwUykmFZJZV3y2aGkLfpwakXuqSJpxqGI89ydFi/QyB0W4sokgSUBUI3VKQ= gitster@git.org
key add -i yoyoyo ssh-dss AAAAB3NzaC1kc3MAAACBAMS9UJWg59QOSgYIJ+Et0/URoF6lIavUmCAJrQC0CO2IbaaV+F5BPkV4EH7YR5jxXxA2r+AVs5ZA/u9JkhQ8L1oDP/P+Zgwv4IDByoZ5ExKMBKg2Y9TmtzRA3ahvEvJJNPUS4Ft50vpj7i3bktY5PjceqrH4jI7amsMMmnqyKy5BAAAAFQDrBuiwuUpSxcBZBTYTvJaJH7MkLwAAAIBX8ORtNuvmraoVEUgwp+GFlo/ql28yVM1KfT1WKZdUnzUvVloTPdTDflxxvjqwM8zaXNhaspAQO7bCBGHV6Cgq0QTjEi8voSQyAG4m+PGtzmGPL5tovmm3VwEZgU68Ya3JAVFHy3AFxE4sfiW4XLcy1YJ77JEdCgAqfPtn+r6PEgAAAIEAqt6kHkR+ArcJCo03CMx/O0gQh93pl/V6nbTbNOKVCUlMAPuvqXttkwuw/kUdywgMeR4M6RKfjOSvpiJ/F4sd5x8Lyelh6qQWcUCZ2GbFgj1pHZJ5MwUykmFZJZV3y2aGkLfpwakXuqSJpxqGI89ydFi/QyB0W4sokgSUBUI3VKQ= yoyoyo@gmail.com
auth  add  gitty  hi
auth  add  -i  gitster  hi
$
```

The output of 'dump' piped to `xargs -L 1 sudo gsb.sh` will recreate the system state.

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
