#!/bin/bash

# get user agreement to brick their system
echo "$0: this test unfortunately modifies system state. OK to proceed? (yes|no)" >&2
read ACK
if [ ! `echo $ACK | grep ^[Yy]` ]; then
	exit 1
fi
# get sudo authorization
sudo echo "thanks for admin privileges ;)"

set -e

# 0. sudo mkdir -p /usr/src

# 1. store output of the following commands in a local file:
#	- cat /etc/fstab
#	- getent passwd
#	- getent group
#	- sudo find -type d /usr/src

# 2. test users and keys
sudo ./gsb.sh user add a
sudo ./gsb.sh key add a [key_a]
sudo ./gsb.sh key add a [key_a]
sudo ./gsb.sh key add a [key_b]
sudo ./gsb.sh user add b
sudo ./gsb.sh key add b [key_a]
sudo ./gsb.sh user add -d c
sudo ./gsb.sh key add -d c [key_b]
sudo ./gsb.sh key add c [key_a] # should fail
# test lists look kosher
sudo ./gsb.sh user ls
sudo ./gsb.sh user ls -d

# 3. test repos
sudo ./gsb.sh repo add ra
sudo ./gsb.sh repo add rb
sudo ./gsb.sh repo add -a rc
# test lists look kosher
sudo ./gsb.sh repo ls
sudo ./gsb.sh repo ls -a

# 4. test auths
sudo ./gsb.sh auth add a ra
sudo ./gsb.sh auth add a rb
sudo ./gsb.sh auth add a -a rc
sudo ./gsb.sh auth add b ra
sudo ./gsb.sh auth add b rb
sudo ./gsb.sh auth add b -a rc
sudo ./gsb.sh auth add -d c ra
sudo ./gsb.sh auth add -d c rb
sudo ./gsb.sh auth add -d c -a rc
# test lists look kosher
sudo ./gsb/sh auth ls
sudo ./gsb/sh auth ls -a
sudo ./gsb/sh auth ls -d
sudo ./gsb/sh auth ls -a -d

# 5. test disabling user and archiving repo
sudo ./gsb.sh user mod -d b
sudo ./gsb.sh repo mod -a rb
# test lists look kosher
sudo ./gsb.sh dump

# 6. test enabling user and enabling repo
sudo ./gsb.sh user mod c
sudo ./gsb.sh repo mod rc
# test lists look kosher
sudo ./gsb.sh dump

# 7. delete everyting
sudo ./gsb.sh user del a
sudo ./gsb.sh user del c
sudo ./gsb.sh user del -d b
sudo ./gsb.sh repo del ra
sudo ./gsb.sh repo del rc
sudo ./gsb.sh repo del -a rb
# test lists look kosher
sudo ./gsb.sh dump

# 8. re-capture output as in 1) and diff against pre-test output
