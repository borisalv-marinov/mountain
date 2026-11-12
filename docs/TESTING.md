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
- [x] Task 7
- [ ] Task 8
- [x] Task 9
- [x] Task 10
- [x] Task 10b: glass look + desktop icons

## Notes

- Squad (Steam app 393380) on ProtonDB, checked 2026-11-10: tier Gold (best reported Platinum), 648 reports, strong confidence. Anti-cheat (EAC) works on Linux; re-check before relying on it.
- Bazzite ships `steam` as an RPM but removes `gamemode` (build_files/bazzite/08-install-steam-lutris.sh), so check_phase6 tests only `steam`.
- Task 7 changes: Bazzite's update timer is `uupd.timer` (was daily 04:00, https://github.com/ublue-os/uupd/blob/main/uupd.timer); a drop-in now sets `OnCalendar=weekly` (Persistent=true kept). Enabled by https://github.com/ublue-os/bazzite/blob/main/build_files/bazzite/12-finalize.sh
- Task 7: `90-mountain.conf` sets `fq` + `bbr`. Bazzite already sets bbr (https://github.com/ublue-os/bazzite/blob/main/system_files/desktop/shared/usr/lib/sysctl.d/75-networking.conf) and no qdisc, so no conflict.
- Task 7: no services disabled. Bazzite already disables/masks its optional ones (12-finalize.sh, 07-install-packages.sh); nothing left that is clearly useless. VM baseline `free -m` still to be recorded by the owner.
- New desktop layout applies to new users; existing users: System Settings → Global Theme → Mountain → apply with 'Desktop and window layout' ticked.
- vm-test and Try Mountain run without a GPU, so Lite mode turns off blur there — judge the glass look on real hardware.

## Real-use test (vm-test) and trends

vm-test now boots the image on a recent QEMU (Fedora container) with `virtio-vga` and clicks through real use via QMP:
start menu → search "settings" → Settings, double-click a desktop folder, File Explorer, open a photo/PDF/text file
(Gwenview/Okular/Notepad), file-type defaults (video/music/office/zip), drag a file into a folder, Steam, GeForce NOW,
all four AI launchers (dry run) plus a real Codex install, top bar off/on, start-menu latency, logout, two reboots and
a clean power-off. Every step leaves a screenshot in the `vm-test-report` artifact (`shots/`).

Triggered runs (`workflow_run`) use the workflow file from `main`; to test a branch's new vm-test steps run
`gh workflow run vm-test.yml --ref <branch>`.

| Date | Image | Boot (systemd-analyze) | Desktop RAM used | Login → desktop | Start-menu latency |
|---|---|---|---|---|---|
| 2026-11-11 | v2 (main) | 23.2 s | 1535 MB | ~120 s fixed wait | — |
| 2026-11-11 | v3 wave 1 | 17.2 s | 1464 MB | — | — |
| 2026-11-11 | v3 wave 2 | 23.5 s* | 1489 MB | 3 s | 188 ms |

\* first boot of a fresh disk with a 40 GiB root (bigger btrfs to set up); the v2/wave-1 numbers were on a smaller disk.
Latency is measured from the Windows key (QMP) to the first changed frame, including screendump overhead.

Notes
- In VMs KWin renders with llvmpipe (no GPU), so lite mode turns blur and animations off there.
- File Explorer command bar: `/etc/skel/.local/share/kxmlgui5/dolphin/dolphinui.rc` is pinned to Dolphin 26.08 (`version="49"`); if Dolphin ships a newer version, KXmlGui ignores the copy and the default toolbar returns — bump it from `src/dolphinui.rc` of the new release.
- `qdbus6` is not installed on Bazzite; scripts use `dbus-send`.
- Desktop layout, places and the File Explorer bar apply to new users. Existing users: Settings → Global Theme →
  Mountain (tick "Desktop and window layout"); names, icons, file types and logos are system-wide.
| 2026-11-12 | v5 first wave (old look) | 19.7 s | 1533 MB | 3 s (autologin) | 176 ms |
| 2026-11-12 | v5 black glass | 24.7 s* | 1499 MB | 6 s (password typed at the lock screen) | 190 ms |

\* first boot of a fresh disk; boot varies ±5 s between runs on the CI machines.

### v5 UI cost and open times (vm-test, software rendering, 1280×800)

| Measure | v5 black glass | Budget in vm-test |
|---|---|---|
| plasmashell idle | 1.1 % CPU, 668 MB | RAM at desktop within 10 % of 1520 MB |
| kwin idle | 3.1 % CPU, 315 MB | — |
| plasmashell / kwin with the start menu open | 1.0 % / 3.0 % CPU, +1 / +2 MB | — |
| File Explorer open (cold / warm) | 205 / 195 ms | INFO (real-PC budget: warm < 400 ms) |
| Settings open (cold / warm) | 285 / 282 ms | INFO |
| Terminal open (cold / warm) | 198 / 286 ms | INFO |
| VS Code open (cold / warm) | 193 / 204 ms | INFO |
| Alt+Tab | 143 ms | INFO |
| Start menu | 190 ms | fail above 210 ms (baseline 175 ms + 20 %) |

Open time is measured to the first changed frame after the launch command (QMP screendump), so it is the moment the
window starts to appear, not when it is fully drawn. The new glass look costs no extra CPU at idle: the theme is SVG,
blur stays in KWin, and the Settings and quick-settings panels have no animations or shaders.
