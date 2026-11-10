# Mountain testing guide

## How to test a new build

1. In VirtualBox, take a snapshot of the test VM first, so you can always go back.
2. First time only, switch the VM to the Mountain image for your branch or main:
   `sudo bootc switch ghcr.io/borisalv-marinov/mountain:<tag>`
   then reboot.
3. Later builds: run `sudo bootc upgrade`, then reboot.
4. Check the phase checklist for the task you are testing.

## How to roll back

- Restart the VM and pick the previous entry in the boot menu, or
- run `sudo bootc rollback` and reboot.

## Progress

- [x] Task 0
- [x] Task 1
- [x] Task 2
- [x] Task 3
- [x] Task 4
- [x] Task 5
- [x] Task 6
- [ ] Task 7
- [ ] Task 8
- [ ] Task 9
- [ ] Task 10

## Notes

- Squad (Steam app 393380) on ProtonDB, checked 2026-11-10: tier Gold (best reported Platinum), 648 reports, strong confidence. Anti-cheat (EAC) works on Linux; re-check before relying on it.
- Bazzite ships `steam` as an RPM but removes `gamemode` (build_files/bazzite/08-install-steam-lutris.sh), so check_phase6 tests only `steam`.
