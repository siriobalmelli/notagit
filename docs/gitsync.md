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
gitsync.sh [repo_dir] [local_branch] [remote] [remote_branch]
```

## Examples

### Running locally

```bash
gitsync.sh /some/repo master origin master
```

### As a `cron` job

Using `crontab -e`:

```bash
PATH=/usr/sbin:/usr/bin

* * * * * gitsync.sh /home/joe/git-shell_bind master origin master
```
