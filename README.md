---
title: README
order: 10
---

# git-shell_bind

A BASH script to administer GIT repos on a server, which are accessed via SSH only.

This documentation as a [web page](https://siriobalmelli.github.io/git-shell_bind/)

## Why

### Setting up and administering a *secure* git server

... can be kind of a pain.

This is solved by [gsb.sh](./gsb.sh), which was thought up to be:

-	Secure
-	Simple
-	Use existing mechanisms only: introduce no new (bug-prone) code

See the [gsb.sh documentation](docs/gsb.md).

### Continuously updating a git repo from a remote source

... *safely*.

There seems to be no tool for this.

This is requires care when development/commits may be happening in either
	(or both) locations and the wish is to **avoid** merges.

Use this script (e.g. as a `cron` job) to:

-	syncronize multiple development machines in the background,
		while you're working on any one of them.
-	have a server pull changes from an upstream repo
		(e.g. for CI work, using a `post-merge` hook)

See the [gitsync.sh documentation](docs/gitsync.md).

## Installation

[gsb.sh](./gsb.sh) and [gitsync.sh](./gitsync.sh) can be run directly from
	the repo directory.

On a production server, they probably belong in `/usr/sbin`.
To put them there, you can run `sudo make install`.

## Contribution

Contributions are always welcome, in order of preference:

-	Fork and send a pull request
-	Open an issue
-	send me a mail at <sirio.bm@gmail.com>

## Documentation

Docs are written in [Markdown](https://daringfireball.net/projects/markdown/syntax)
	and then auto-generated with [Jekyll](https://jekyllrb.com/).

If you would like to hack on the doucumentation:

-	place any new files in the [docs](./docs) directory
-	files should have an `.md` extension
-	make any links relative to the *root* of the repo; e.g.: `[gsb](docs/gsb.md)`
-	please put a `title:` frontmatter at the top of every file

## TODO

- migrate gsb to `getopt` for friendlier interface
- Show '-w' flag on `gsb.sh auth ls`
- Quotas on .git repos (to stop users from crashing server)
- Possible to have a dedicated directory for .git temp files when read-only users
	are pulling?
- Pen testing
