---
title: gitsync
---

# gitsync.sh

Safely update a git repo from a remote source.

Emphasis on *safety*: make no change which is not guaranteed to be OK.
This makes the script safe to run automatically, even while you occasionally
	work on both the local or the remote repo.

## Synopsis

```
gitsync.sh [-v] REPO_DIR LOCAL_BRANCH REMOTE REMOTE_BRANCH
	-v	:	verbose: Print command output.
			Default behavior is to only print errors.
```

## Examples

### Running locally

```bash
gitsync.sh /some/repo master origin master
```

Works with bare repos as well, no change in syntax:
	(if you're not familiar: a bare repo is what a server stores,
	you can't work inside it)

```bash
gitsync.sh /bare/repo master other_server master
```

### As a `cron` job

Using `crontab -e`:

```bash
PATH=/usr/sbin:/usr/bin

* * * * * gitsync.sh /home/joe/git-shell_bind master origin master
```
