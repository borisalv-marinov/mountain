# Mountain v6 attack test (red team)

Run inside the vm-test VM only (the owner's own system, authorized). Every attack is a step in
`.github/workflows/vm-test.yml` ("attack: …" and "Active Protection: …" rows in the report). The attacker's
network is a namespace on a veth, so its traffic reaches the PC through firewalld's default zone, like another
computer on the same Wi-Fi.

| Attack | Expected | Actual (vm-test run 43618372614, commit e1394c8) |
|---|---|---|
| Port scan of ports 1–1024 and common game/remote ports from the network | Nothing open (22 is the test VM's own SSH; the shipped image has no SSH server) | PASS: only port 22 open (the test VM's own SSH) |
| Password brute force over SSH (6 wrong passwords) | Account locked for 5 minutes; the right password is then refused | PASS: locked out after the wrong passwords; control login with the right password worked before (GOT-IN) |
| Admin (wheel) `sudo` without a password | Refused | PASS: "a password is required", refused |
| Admin polkit action (`pkexec`) without a password | Refused | PASS: refused (no password agent) |
| Write the system (`/usr`) as root | Impossible: read-only image | PASS: "Read-only file system" |
| SUID programs in user-writable places | None | PASS: 0 found |
| SELinux | Stays enforcing | PASS: Enforcing (26 denials this boot, INFO) |
| EICAR in Downloads, `/tmp`, a USB drive, an attachment-like folder, a folder moved to the Desktop | Caught after the file is written (a burst is gathered for up to 10 s, then scanned at low priority; the test allows 120 s) and quarantined | PASS: caught and quarantined in Downloads (right-click scan, automatic), /tmp, USB drive, attachment-like folder, folder moved to the Desktop |
| EICAR downloaded from the web | INFO only, not a pass/fail check (needs the internet; the server may refuse CI machines) | INFO: not downloaded (no result, as expected) |
| An archive is extracted (5 or more files in one folder under Downloads, Desktop or Documents) | All extracted files are scanned in one scan, including .txt and images; clean: one notification "Checked N extracted files: no threats found."; a threat is quarantined with the usual alert instead. Covered by tests/test-protect.sh with a stand-in scanner; not yet exercised with a real Ark or Dolphin extraction in the VM. An archive that takes longer than the 10 s gather window is split into batches, one notice each | FAIL: one scan and one result for the folder (PASS), but an EICAR named .txt inside it was not caught |
| A new unsigned script; persistence: a new autostart entry or link to one, a user service, a `.bashrc` change | Flagged "unverified" in Active Protection (files over 400 MB are listed as "too large to scan", never passed as clean) | PASS: unsigned script, new autostart entry, link into autostart, user service and .bashrc change all flagged (crafted names handled safely) |
| The Active Protection watcher is killed | Restarts by itself within about a minute, and tells the user it stopped | PASS: restarted by itself (1 active); the stop notification is INFO (logged, 1) |
| Cost of a full virus scan | Runtime, CPU time and memory peak of the scan unit, reported as INFO (no limit is asserted); Active Protection idle: ≤ 150 MB RAM, ~0 % CPU | PASS: idle RAM 3 MB, CPU 0.00 % over 30 s; scan unit 148 ms runtime, 68 ms CPU (INFO) |
| A Flatpak chat app reads `~/Documents` and `~/.ssh` | Not visible inside the sandbox | PASS: no home folder in all 5 apps; cannot read ~/.ssh or ~/Documents |
| A test service on port 8765 | Answers inside the PC, blocked from outside | PASS: 200 inside the PC, http 000 from outside |
| Fake ransomware encrypts a folder | Restored from Previous versions | PASS: encrypted files restored (precious-2) |
| A broken system file in `/etc` | Repaired from the image's copy (`mountain-security repair-etc`) | PASS: /etc/xdg/kdeglobals repaired |
| Deleted desktop settings | Restored from Previous versions | PASS: restored (45) |
| A bad update | Go back to the previous version boots the old one | PASS: previous version booted |
| Disk filled to the last 64 MB | Still boots | PASS: still boots with 64 MB free |

Not tested in this run: Allow-an-app firewall rows, definitions download (Initialization error: fixed after this run, see `mountain-security update`), and AV scan with the real database (no definitions in the VM). Holes found and fixed are listed under the run that found them.
