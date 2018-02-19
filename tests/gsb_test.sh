#!/bin/bash

# get user agreement to brick their system
echo "$0: this test unfortunately modifies system state. OK to proceed? (yes|no)" >&2
read ACK
if [ ! `echo $ACK | grep ^[Yy]` ]; then
	exit 0
fi
# get sudo authorization
sudo echo "Thanks for admin privileges ;)"

set -e


# remove any diff files created
# -f flag means don't barf or ask questions
#	rm_diff_files()
rm_diff_files()
{
	sudo rm -f ./*.txt
}

#	store_files()
# Store files that require verification
#+	after we have done the tests.
#		$1	:	suffix
store_files()
{
	cat /etc/fstab > ./fstab_${1}.txt
	getent passwd > ./passwd_${1}.txt
	getent group > ./group_${1}.txt
	sudo find "/usr/src" -type d 2>/dev/null >./find_${1}.txt || true
}

#	comp_expect()
# Compare $OUT and $EXPECT
#	$*	:	commands to exec
comp_expect()
{
	# tabulate EXPECT (gsb tabulates its output)
	EXPECT=$(echo "$EXPECT" | column -t)
	OUT="$($*)"
	if [[ $OUT != $EXPECT ]]; then
		echo -e "exec: $*\ngot:\n$OUT\n\nexpected:\n$EXPECT"
		exit 1
	fi
}

# cleanup from any previous possible failures
rm_diff_files
# Get into our own directory
pushd $(dirname "$0")
sudo mkdir -p /usr/src
# 1. store output of the following commands in a local file:
store_files "a"


# 2. test users and keys
sudo ../gsb.sh user add ua
sudo ../gsb.sh key add ua ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCnkZBkhDTKKjzeU4/8I+JXC5Ok8aizbFmWPE2/fmGs14h7Wn6HIEpbkzFpnhFwu8sY5M19+KxonGHB9dPigiccWd7uOtbmQQzTzc/qwAp13WCt4slXtwV2ZimDhU3zm6XTFFFZC3SVdXJajL0bSFU1+ZZBhvYY4ulBwyUuYaArXMBc+RLqEXxuH6HTLBYX9Sd7W0cqSCFS4mt3jYKRmd+42XzLirRugaBh32y/mnbotiV2x82Yp1vyj35cvKTA04oUTVYkiui4o+xre6+JboxFeJCT+xEmgAgcU2a7q8763PMziUYgFDJd+5plGKe19FwLHgEirakmFUN/h/85MtfD tony@tbox-4
sudo ../gsb.sh key add ua ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCnkZBkhDTKKjzeU4/8I+JXC5Ok8aizbFmWPE2/fmGs14h7Wn6HIEpbkzFpnhFwu8sY5M19+KxonGHB9dPigiccWd7uOtbmQQzTzc/qwAp13WCt4slXtwV2ZimDhU3zm6XTFFFZC3SVdXJajL0bSFU1+ZZBhvYY4ulBwyUuYaArXMBc+RLqEXxuH6HTLBYX9Sd7W0cqSCFS4mt3jYKRmd+42XzLirRugaBh32y/mnbotiV2x82Yp1vyj35cvKTA04oUTVYkiui4o+xre6+JboxFeJCT+xEmgAgcU2a7q8763PMziUYgFDJd+5plGKe19FwLHgEirakmFUN/h/85MtfD tony@tbox-4
sudo ../gsb.sh key add ua ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDnPC60fvRr7tRVWnQqD2eTgrf3DkKskATcdpA3eEWxxKRv9MP554PV2x1bJUYHRLGodElrA6tnMoSS4QRKaTxqggPMdpae7HaqkYh140DUKHULNk0uNwfIQ3JNq6mzPKlK2R66YEVK9r598EFIrIyFuvLM0F9LZcz32OF+HEu777k76H3CYb78ceSNN8RKAgfOtBx4WbEOWoygyB8Nm7GsZQv7GEIpjnyyDb7r6ZSG9JDjq69iO3gBBRtmHCtfeJV3N41ywvNQVTeeMZ9DESNxAe108+8XxU1jvZoiiG+H4gq2vK0wtGWEmJk4u5E/TeTEWJuBXxcSp8wNT57LTLGb tony@tbox-4
sudo ../gsb.sh user add ub
sudo ../gsb.sh key add ub ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCnkZBkhDTKKjzeU4/8I+JXC5Ok8aizbFmWPE2/fmGs14h7Wn6HIEpbkzFpnhFwu8sY5M19+KxonGHB9dPigiccWd7uOtbmQQzTzc/qwAp13WCt4slXtwV2ZimDhU3zm6XTFFFZC3SVdXJajL0bSFU1+ZZBhvYY4ulBwyUuYaArXMBc+RLqEXxuH6HTLBYX9Sd7W0cqSCFS4mt3jYKRmd+42XzLirRugaBh32y/mnbotiV2x82Yp1vyj35cvKTA04oUTVYkiui4o+xre6+JboxFeJCT+xEmgAgcU2a7q8763PMziUYgFDJd+5plGKe19FwLHgEirakmFUN/h/85MtfD tony@tbox-4
sudo ../gsb.sh user add -d uc
sudo ../gsb.sh key add -d uc ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDnPC60fvRr7tRVWnQqD2eTgrf3DkKskATcdpA3eEWxxKRv9MP554PV2x1bJUYHRLGodElrA6tnMoSS4QRKaTxqggPMdpae7HaqkYh140DUKHULNk0uNwfIQ3JNq6mzPKlK2R66YEVK9r598EFIrIyFuvLM0F9LZcz32OF+HEu777k76H3CYb78ceSNN8RKAgfOtBx4WbEOWoygyB8Nm7GsZQv7GEIpjnyyDb7r6ZSG9JDjq69iO3gBBRtmHCtfeJV3N41ywvNQVTeeMZ9DESNxAe108+8XxU1jvZoiiG+H4gq2vK0wtGWEmJk4u5E/TeTEWJuBXxcSp8wNT57LTLGb tony@tbox-4
# should fail
if sudo ../gsb.sh key add uc ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCnkZBkhDTKKjzeU4/8I+JXC5Ok8aizbFmWPE2/fmGs14h7Wn6HIEpbkzFpnhFwu8sY5M19+KxonGHB9dPigiccWd7uOtbmQQzTzc/qwAp13WCt4slXtwV2ZimDhU3zm6XTFFFZC3SVdXJajL0bSFU1+ZZBhvYY4ulBwyUuYaArXMBc+RLqEXxuH6HTLBYX9Sd7W0cqSCFS4mt3jYKRmd+42XzLirRugaBh32y/mnbotiV2x82Yp1vyj35cvKTA04oUTVYkiui4o+xre6+JboxFeJCT+xEmgAgcU2a7q8763PMziUYgFDJd+5plGKe19FwLHgEirakmFUN/h/85MtfD tony@tbox-4 2>/dev/null
then
	echo "adding a key to a disabled user without '-d' flag should fail"
	exit 1
fi

# test lists look kosher
EXPECT=\
"ua
ub"
comp_expect sudo ../gsb.sh user ls
EXPECT=\
"uc"
comp_expect sudo ../gsb.sh user ls -d


# 3. test repos
sudo ../gsb.sh repo add ra
sudo ../gsb.sh repo add rb
sudo ../gsb.sh repo add -a rc

# test lists look kosher
EXPECT=\
"ra
rb"
comp_expect sudo ../gsb.sh repo ls
EXPECT=\
"rc -a"
comp_expect sudo ../gsb.sh repo ls -a


# 4. test auths
sudo ../gsb.sh auth add ua ra
sudo ../gsb.sh auth add ua rb -w
sudo ../gsb.sh auth add ua -a rc
sudo ../gsb.sh auth add ub ra
sudo ../gsb.sh auth add ub rb
sudo ../gsb.sh auth add ub -a rc
sudo ../gsb.sh auth add -d uc ra
sudo ../gsb.sh auth add -d uc rb
sudo ../gsb.sh auth add -d uc -a rc

# test lists look kosher
EXPECT=\
"ua ra
ub ra
ua rb  -w
ub rb"
comp_expect sudo ../gsb.sh auth ls
EXPECT=\
"ua -a rc
ub -a rc"
comp_expect sudo ../gsb.sh auth ls -a
EXPECT=\
"-d  uc  ra
-d  uc  rb"
comp_expect sudo ../gsb.sh auth ls -d
EXPECT=\
"-d uc -a rc"
comp_expect sudo ../gsb.sh auth ls -a -d


# 5. test disabling user and archiving repo
sudo ../gsb.sh user mod -d ub
sudo ../gsb.sh repo mod -a rb


# 6. test enabling user and enabling repo
sudo ../gsb.sh user mod uc
sudo ../gsb.sh repo mod rc


# 7. delete everyting
sudo ../gsb.sh user del ua
sudo ../gsb.sh user del uc
sudo ../gsb.sh user del -d ub
sudo ../gsb.sh repo del ra
sudo ../gsb.sh repo del rc
sudo ../gsb.sh repo del -a rb

# ... should leave nothing
if [[ -n $(sudo ../gsb.sh dump) ]]; then
	echo "system not clean after tests" >&2
	exit 1
fi


# 8. re-capture output as in 1) and diff against pre-test output
store_files "b"
diff ./fstab_a.txt ./fstab_b.txt
diff ./passwd_a.txt ./passwd_b.txt
diff ./group_a.txt ./group_b.txt
diff ./find_a.txt ./find_b.txt
rm_diff_files


popd # leave directory again
echo "success"
exit 0
