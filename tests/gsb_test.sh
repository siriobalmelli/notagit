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

# remove any diff files created
# -f flag means don't barf or ask questions
#	rm_diff_files()
rm_diff_files()
{
	rm -f ./*.txt
}

# cleanup from any previous possible failures
rm_diff_files

# Get into our own directory
pushd $(dirname "$0")

# 0. sudo mkdir -p /usr/src
mkdir -p /usr/src

# 1. store output of the following commands in a local file:
#	- cat /etc/fstab
#	- getent passwd
#	- getent group
#	- sudo find -type d /usr/src

#	store files that require verification
#	after we have done the tests
#	store_files()
store_files()
{
	cat /etc/fstab > ./fstab.txt
	getent passwd > ./passwd.txt
	getent group > ./group.txt
	find "/usr/src" -type d 2>/dev/null > find.txt
}

store_files

# 2. test users and keys
#	user_keys()
users_keys()
{
	sudo ../gsb.sh -v user add a
	sudo ../gsb.sh -v key add a ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCnkZBkhDTKKjzeU4/8I+JXC5Ok8aizbFmWPE2/fmGs14h7Wn6HIEpbkzFpnhFwu8sY5M19+KxonGHB9dPigiccWd7uOtbmQQzTzc/qwAp13WCt4slXtwV2ZimDhU3zm6XTFFFZC3SVdXJajL0bSFU1+ZZBhvYY4ulBwyUuYaArXMBc+RLqEXxuH6HTLBYX9Sd7W0cqSCFS4mt3jYKRmd+42XzLirRugaBh32y/mnbotiV2x82Yp1vyj35cvKTA04oUTVYkiui4o+xre6+JboxFeJCT+xEmgAgcU2a7q8763PMziUYgFDJd+5plGKe19FwLHgEirakmFUN/h/85MtfD tony@tbox-4
	sudo ../gsb.sh -v key add a ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCnkZBkhDTKKjzeU4/8I+JXC5Ok8aizbFmWPE2/fmGs14h7Wn6HIEpbkzFpnhFwu8sY5M19+KxonGHB9dPigiccWd7uOtbmQQzTzc/qwAp13WCt4slXtwV2ZimDhU3zm6XTFFFZC3SVdXJajL0bSFU1+ZZBhvYY4ulBwyUuYaArXMBc+RLqEXxuH6HTLBYX9Sd7W0cqSCFS4mt3jYKRmd+42XzLirRugaBh32y/mnbotiV2x82Yp1vyj35cvKTA04oUTVYkiui4o+xre6+JboxFeJCT+xEmgAgcU2a7q8763PMziUYgFDJd+5plGKe19FwLHgEirakmFUN/h/85MtfD tony@tbox-4
	sudo ../gsb.sh -v key add a ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDnPC60fvRr7tRVWnQqD2eTgrf3DkKskATcdpA3eEWxxKRv9MP554PV2x1bJUYHRLGodElrA6tnMoSS4QRKaTxqggPMdpae7HaqkYh140DUKHULNk0uNwfIQ3JNq6mzPKlK2R66YEVK9r598EFIrIyFuvLM0F9LZcz32OF+HEu777k76H3CYb78ceSNN8RKAgfOtBx4WbEOWoygyB8Nm7GsZQv7GEIpjnyyDb7r6ZSG9JDjq69iO3gBBRtmHCtfeJV3N41ywvNQVTeeMZ9DESNxAe108+8XxU1jvZoiiG+H4gq2vK0wtGWEmJk4u5E/TeTEWJuBXxcSp8wNT57LTLGb tony@tbox-4
	sudo ../gsb.sh -v user add b
	sudo ../gsb.sh -v key add b ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCnkZBkhDTKKjzeU4/8I+JXC5Ok8aizbFmWPE2/fmGs14h7Wn6HIEpbkzFpnhFwu8sY5M19+KxonGHB9dPigiccWd7uOtbmQQzTzc/qwAp13WCt4slXtwV2ZimDhU3zm6XTFFFZC3SVdXJajL0bSFU1+ZZBhvYY4ulBwyUuYaArXMBc+RLqEXxuH6HTLBYX9Sd7W0cqSCFS4mt3jYKRmd+42XzLirRugaBh32y/mnbotiV2x82Yp1vyj35cvKTA04oUTVYkiui4o+xre6+JboxFeJCT+xEmgAgcU2a7q8763PMziUYgFDJd+5plGKe19FwLHgEirakmFUN/h/85MtfD tony@tbox-4
	sudo ../gsb.sh -v user add -d c
	sudo ../gsb.sh -v key add -d c ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDnPC60fvRr7tRVWnQqD2eTgrf3DkKskATcdpA3eEWxxKRv9MP554PV2x1bJUYHRLGodElrA6tnMoSS4QRKaTxqggPMdpae7HaqkYh140DUKHULNk0uNwfIQ3JNq6mzPKlK2R66YEVK9r598EFIrIyFuvLM0F9LZcz32OF+HEu777k76H3CYb78ceSNN8RKAgfOtBx4WbEOWoygyB8Nm7GsZQv7GEIpjnyyDb7r6ZSG9JDjq69iO3gBBRtmHCtfeJV3N41ywvNQVTeeMZ9DESNxAe108+8XxU1jvZoiiG+H4gq2vK0wtGWEmJk4u5E/TeTEWJuBXxcSp8wNT57LTLGb tony@tbox-4
# should fail so unset -e
set +e
	sudo ../gsb.sh -v key add c ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCnkZBkhDTKKjzeU4/8I+JXC5Ok8aizbFmWPE2/fmGs14h7Wn6HIEpbkzFpnhFwu8sY5M19+KxonGHB9dPigiccWd7uOtbmQQzTzc/qwAp13WCt4slXtwV2ZimDhU3zm6XTFFFZC3SVdXJajL0bSFU1+ZZBhvYY4ulBwyUuYaArXMBc+RLqEXxuH6HTLBYX9Sd7W0cqSCFS4mt3jYKRmd+42XzLirRugaBh32y/mnbotiV2x82Yp1vyj35cvKTA04oUTVYkiui4o+xre6+JboxFeJCT+xEmgAgcU2a7q8763PMziUYgFDJd+5plGKe19FwLHgEirakmFUN/h/85MtfD tony@tbox-4 
set -e
}

users_keys

# test lists look kosher
sudo ../gsb.sh user ls
sudo ../gsb.sh user ls -d

# 3. test repos
#	repos()
repos()
{
	sudo ../gsb.sh -v repo add ra
	sudo ../gsb.sh -v repo add rb
	sudo ../gsb.sh -v repo add -a rc
}

repos

# test lists look kosher
sudo ../gsb.sh repo ls
sudo ../gsb.sh repo ls -a

# 4. test auths
auths()
{
	sudo ../gsb.sh -v auth add a ra
	sudo ../gsb.sh -v auth add a rb
	sudo ../gsb.sh -v auth add a -a rc
	sudo ../gsb.sh -v auth add b ra
	sudo ../gsb.sh -v auth add b rb
	sudo ../gsb.sh -v auth add b -a rc
	sudo ../gsb.sh -v auth add -d c ra
	sudo ../gsb.sh -v auth add -d c rb
	sudo ../gsb.sh -v auth add -d c -a rc
}

auths

# test lists look kosher
sudo ../gsb.sh auth ls
sudo ../gsb.sh auth ls -a
sudo ../gsb.sh auth ls -d
sudo ../gsb.sh auth ls -a -d

# 5. test disabling user and archiving repo
user_disable()
{
	sudo ../gsb.sh -v user mod -d b
	sudo ../gsb.sh -v repo mod -a rb
}

user_disable

# test lists look kosher
sudo ../gsb.sh dump

# 6. test enabling user and enabling repo
user_mod()
{
	sudo ../gsb.sh -v user mod c
	sudo ../gsb.sh -v repo mod rc
}

user_mod

# test lists look kosher
sudo ../gsb.sh dump

# 7. delete everyting
delete_all()
{
	sudo ../gsb.sh user del a
	sudo ../gsb.sh user del c
	sudo ../gsb.sh user del -d b
	sudo ../gsb.sh repo del ra
	sudo ../gsb.sh repo del rc
	sudo ../gsb.sh repo del -a rb
}

delete_all

# test lists look kosher
sudo ../gsb.sh dump

# 8. re-capture output as in 1) and diff against pre-test output
diff_data()
{
	cat /etc/fstab > ./fstab_a.txt
	getent passwd > ./passwd_a.txt
	getent group > ./group_a.txt
	find "/usr/src" -type d 2>/dev/null > find_a.txt

	diff ./fstab.txt ./fstab_a.txt
	diff ./passwd.txt ./passwd_a.txt
	diff ./group.txt ./group_a.txt
	diff ./find.txt ./find_a.txt
}

diff_data
rm_diff_files

popd # leave directory again
exit 0
