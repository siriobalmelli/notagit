---
title: README
order: 10
---

# notagit

Utilities for managing [Git](https://git-scm.com/) repositories and servers
	using only [bash](https://en.wikipedia.org/wiki/Bash_%28Unix_shell%29)
	and [ssh](https://en.wikipedia.org/wiki/Secure_Shell).

-	[Repository](https://github.com/siriobalmelli/notagit)
-	[Documentation](https://siriobalmelli.github.io/notagit/)

Read below for a quick description of each utility.

## Installation

[gsb.sh](./gsb.sh) and [gitsync.sh](./gitsync.sh) can be run directly from
	the repo directory.

On a production server, they probably belong in `/usr/sbin`.
To put them there, you can run

```bash
make test && make sudo make install
```

## gsb.sh (git-shell_bind) {#GSB}

A bash script to administer Git repos on a server;
	accessed via [ssh keypairs](https://www.ssh.com/ssh/key/) only.

### Why

Setting up and administering a *secure* git server can be kind of a pain.

This is solved by [gsb.sh](./gsb.sh), which was thought up to be:

-	Secure
-	Simple
-	Use existing mechanisms only: introduce no new (bug-prone) code

### How

1. Putting each bare repo inside the root-only `/usr/src/git` location.
1. Making a system group for each repo.
1. Giving each user a system account allowing only:
	- [git-shell](https://git-scm.com/docs/git-shell)
	- ssh login with keypairs
1. Selectively bind-mounting authorized repos into the relevant user's
	home dir to give read access.
1. Selectively adding the user to the supplementary group of the git
	repo to give write access.
1. Using ONLY existing system mechanisms to manage this
	- do not write anything
	- do not require sysadmins to track another config file

See the [gsb.sh documentation](docs/gsb.md) for details and examples.

## gitsync.sh

Continuously updating a git repo from a remote source ... *safely*.

There seems to be no tool for this; especially one which handles bare
	repos (synchronizing servers between each other).

This is requires care when development/commits may be happening in either
	(or both) locations and the wish is to **avoid** any unexpected behavior.

Use this script (e.g. as a `cron` job) to:

- Syncronize multiple development machines in the background,
	while you're working on any one of them.
- Have a server pull changes from an upstream repo
	(e.g. for CI work, using a `post-merge` hook).
- Synchronize bare repos of two [gsb.sh](#GSB) servers both ways,
	to make them redundant.

See the [gitsync.sh documentation](docs/gitsync.md).

## Contribution

Contributions are always welcome, in order of preference:

-	Fork and send a pull request
-	Open an issue
-	send me a mail at <sirio.bm@gmail.com>

## Documentation

Docs are written in [Markdown](https://daringfireball.net/projects/markdown/syntax)
	and then auto-generated with [Jekyll](https://jekyllrb.com/).

If you would like to hack on the documentation:

-	place any new files in the [docs](./docs) directory
-	files should have an `.md` extension
-	make any links relative to the *root* of the repo; e.g.: `[gsb](docs/gsb.md)`
-	please put a `title:` frontmatter at the top of every file

## TODO

- Show '-w' flag on `gsb.sh auth ls`
- Quotas on .git repos (to stop users from crashing server)
- Possible to have a dedicated directory for .git temp files when read-only users
	are pulling?
- Pen testing
- Tests for gsb.sh (need a VM or at the very least a docker?)

## Naming

I called it `notagit` since by using these utilities, sysadmins everywhere
	can demonstrate their outstanding, pragmatic intelligence and deep wisdom
	in the way of unix things ;)

Also, it is literally *not* a Git, nor is it some extension to Git in
	*yet-another-language-with-dependencies*.
