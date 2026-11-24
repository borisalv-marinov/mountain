# TEST ONLY (iso.yml): unattended install. Never shipped. @SSHKEY@ is replaced by the workflow with a throwaway public key.
text
lang en_US.UTF-8
keyboard us
timezone UTC --utc
zerombr
clearpart --all --initlabel
autopart --type=btrfs
rootpw --lock
user --name=tester --groups=wheel --plaintext --password=123
sshkey --username=tester "@SSHKEY@"
reboot
%post
systemctl enable sshd
firewall-offline-cmd --zone=mountain --add-service=ssh || true
echo 'tester ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/zz-iso-test
%end
