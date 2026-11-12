# Mountain v6 attack test (red team)

Run inside the vm-test VM only (the owner's own system, authorized). Every attack is a step in
`.github/workflows/vm-test.yml` ("attack: …" and "Active Protection: …" rows in the report). The attacker's
network is a namespace on a veth, so its traffic reaches the PC through firewalld's default zone, like another
computer on the same Wi-Fi.

| Attack | Expected | Actual (vm-test) |
|---|---|---|
| Port scan of ports 1–1024 and common game/remote ports from the network | Nothing open (22 is the test VM's own SSH; the shipped image has no SSH server) | see the latest run |
| Password brute force over SSH (6 wrong passwords) | Account locked for 5 minutes; the right password is then refused | see the latest run |
| Admin (wheel) `sudo` without a password | Refused | see the latest run |
| Admin polkit action (`pkexec`) without a password | Refused | see the latest run |
| Write the system (`/usr`) as root | Impossible: read-only image | see the latest run |
| SUID programs in user-writable places | None | see the latest run |
| SELinux | Stays enforcing | see the latest run |
| EICAR in Downloads, `/tmp`, a USB drive, an attachment-like folder | Caught within seconds and quarantined | see the latest run |
| EICAR downloaded from the web | Caught (best effort: needs the internet) | see the latest run |
| A new unsigned script, a new autostart entry (persistence) | Flagged "unverified" in Active Protection | see the latest run |
| A Flatpak chat app reads `~/Documents` and `~/.ssh` | Not visible inside the sandbox | see the latest run |
| A test service on port 8765 | Answers inside the PC, blocked from outside | see the latest run |
| Fake ransomware encrypts a folder | Restored from Previous versions | see the latest run |
| A broken system file in `/etc` | Repaired from the image's copy (`mountain-security repair-etc`) | see the latest run |
| Deleted desktop settings | Restored from Previous versions | see the latest run |
| A bad update | Go back to the previous version boots the old one | see the latest run |
| Disk filled to the last 64 MB | Still boots | see the latest run |

Holes found and fixed are listed under the run that found them.
