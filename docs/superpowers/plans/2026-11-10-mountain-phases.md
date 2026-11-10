# Mountain Phases 0–10 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Read `docs/AI-WORKFLOW.md` first — it sets the model, token and testing rules.

**Goal:** Turn the BlueBuild template into Mountain: one light, stable Linux image for gaming, cloud gaming, Discord and coding on almost any x86_64 PC.

**Architecture:** BlueBuild recipe on top of `ghcr.io/ublue-os/bazzite:stable` (KDE). Shared modules live in `recipes/common.yml`; `recipes/recipe.yml` (AMD/Intel) and `recipes/recipe-nvidia.yml` (NVIDIA) only set name + base image. Our own files go in `files/system/` (copied to `/`). GitHub Actions builds, signs, then runs `tests/check-image.sh` inside the built image on every push.

**Tech Stack:** BlueBuild (recipe-v1 schema, modules `files`, `rpm-ostree`, `default-flatpaks@v1`, `systemd`, `script`, `signing`), Fedora Atomic / bootc, Flatpak (Flathub), KDE Plasma, bash, GitHub Actions, cosign, VirtualBox for manual tests.

**Spec:** Conversation requirements, summarized in Global Constraints below (no separate spec file).

## Global Constraints

- System name: `Mountain`. The display name appears in exactly one place: `files/system/usr/share/mountain/config` (`MOUNTAIN_NAME="Mountain"`). Image names: `mountain`, `mountain-nvidia`.
- One system for everyone. No editions. Gamers, coders and both use the same image.
- Base: `ghcr.io/ublue-os/bazzite`, tag `stable`. NVIDIA: `ghcr.io/ublue-os/bazzite-nvidia`, tag `stable`. Never `testing`/`unstable`.
- Idle RAM target after login, no apps open: ≤ 1.5 GB (measure with `free -m`, "used" column).
- Automatic updates: at most once a week; never download during a game (Bazzite update timer adjusted, not removed).
- Repo: `borisalv-marinov/mountain`. Image registry: `ghcr.io/borisalv-marinov/`.
- `cosign.key` is never committed. `.gitignore` keeps `cosign.key`, `*.iso`, `*.vdi`.
- Verified Flathub IDs (checked 2026-11-10): `dev.vencord.Vesktop`, `com.discordapp.Discord`, `com.microsoft.Edge`, `org.onlyoffice.desktopeditors`, `com.heroicgameslauncher.hgl`. Boosteroid and GeForce NOW have no Flathub app → web apps through Edge.
- Cloud URLs: GeForce NOW `https://play.geforcenow.com`, Xbox Cloud `https://www.xbox.com/play`, Boosteroid `https://cloud.boosteroid.com`.
- VS Code repo: `https://packages.microsoft.com/yumrepos/vscode/config.repo`, package `code`.
- One phase per commit/PR. Every phase must pass CI (build + `tests/check-image.sh`) before the user tests it in the VM.
- Commit messages end with the attribution line from `docs/AI-WORKFLOW.md`.

## Review Focus

1. **First boot with no internet** — Flatpaks can't download; system must still boot to desktop and retry later. Test: Task 8 manual check (VM network cable unplugged).
2. **Flatpak ID typo or removed app** — one bad ID can stop the whole first-boot install. Test: Task 0 `check-flathub-ids.sh` runs in CI against every ID in `common.yml`.
3. **Update during play / metered connection** — must not eat bandwidth. Test: Task 7 asserts the update timer interval is weekly.
4. **NVIDIA card added later to an AMD install** (or removed) — GPU check must switch image once, not loop on every boot. Test: Task 9 `check-image.sh` runs the script with a fake `lspci` twice and asserts one switch.
5. **Renaming Mountain later** — changing `MOUNTAIN_NAME` alone must update every visible name. Test: Task 10 asserts no hard-coded "Mountain" outside the config file except image names.

## File Structure

| File | Responsibility |
|---|---|
| `recipes/recipe.yml` | AMD/Intel image: name, base, `from-file: common.yml` |
| `recipes/recipe-nvidia.yml` | NVIDIA image: same, NVIDIA base |
| `recipes/common.yml` | All shared modules, in order |
| `files/system/usr/share/mountain/config` | Name + image refs, single source of truth |
| `files/system/usr/share/applications/mountain-*.desktop` | Cloud-gaming launchers |
| `files/system/usr/lib/sysctl.d/90-mountain.conf` | Network tuning |
| `files/system/usr/lib/systemd/...` | Our services/timer overrides |
| `files/system/usr/libexec/mountain-gpu-check` | NVIDIA auto-switch |
| `files/system/etc/skel/Projects/.keep` | Projects folder for new users |
| `files/scripts/branding.sh` | Build-time: applies name from config |
| `tests/check-image.sh` | Runs inside built image; one `check_*` function per phase |
| `tests/check-flathub-ids.sh` | Runs in CI; every Flatpak ID returns HTTP 200 |
| `.github/workflows/build.yml` | Build matrix + test job |
| `docs/TESTING.md` | Manual VM checklist per phase, for the user |

---

### Task 0: Automatic test workflow (runs on every push)

**Files:** Create `tests/check-image.sh`, `tests/check-flathub-ids.sh`, `docs/TESTING.md`. Modify `.github/workflows/build.yml`.

**Interfaces:**
- Produces: `tests/check-image.sh <phase>` — runs `check_phase1` … `check_phaseN` (all phases up to N); exits non-zero on first failure, printing `FAIL: <what>`. Each later task appends one `check_phaseN` function and bumps `MOUNTAIN_PHASE` in the workflow.
- Produces: helper `assert_cmd <cmd>`, `assert_file <path>`, `assert_grep <pattern> <file>`, `assert_no_rpm <name>`.

- [ ] **Step 1:** Write `tests/check-image.sh` with the helpers and `check_phase0` (asserts `/usr/share/mountain/config` exists — fails now).
- [ ] **Step 2:** Write `tests/check-flathub-ids.sh`: extract IDs from `recipes/common.yml` (lines under `install:` in the default-flatpaks module), `curl -s -o /dev/null -w "%{http_code}" https://flathub.org/api/v2/appstream/<id>`, fail on anything but 200.
- [ ] **Step 3:** Add to `build.yml`: a `lint` job (runs `check-flathub-ids.sh`, YAML check with `yamllint -d relaxed recipes/`), `bluebuild` job `needs: lint`, and a `test` job `needs: bluebuild` that pulls the just-built image and runs `podman run --rm -v $PWD/tests:/tests:ro <image> bash /tests/check-image.sh $MOUNTAIN_PHASE` for each matrix recipe. Image tag: `latest` on `main`; on other branches find the newest tag starting `br-<branch>` via `skopeo list-tags docker://ghcr.io/borisalv-marinov/mountain`. Confirm the real branch-tag format from the first build log and fix the filter if it differs.
- [ ] **Step 4:** Create `files/system/usr/share/mountain/config` with `MOUNTAIN_NAME="Mountain"`, `MOUNTAIN_IMAGE="ghcr.io/borisalv-marinov/mountain"`, `MOUNTAIN_IMAGE_NVIDIA="ghcr.io/borisalv-marinov/mountain-nvidia"`.
- [ ] **Step 5:** Push; expected: lint ✓, build ✓, test ✓ (`PASS: phase 0`). Write `docs/TESTING.md` header: snapshot → `sudo bootc switch ghcr.io/borisalv-marinov/mountain:<tag>` (first time) or `sudo bootc upgrade` → reboot → phase checklist.
- [ ] **Step 6:** Commit `ci: add image tests and flathub id check`.

### Task 1: Clean base + shared recipe

**Files:** Create `recipes/common.yml`. Modify `recipes/recipe.yml`. Delete `files/scripts/example.sh`.

**Interfaces:** Produces `recipes/common.yml` with modules in this order: `files` → `rpm-ostree` → `default-flatpaks@v1` → `systemd` → `script` → `signing`. Later tasks only add entries inside these modules.

- [ ] **Step 1:** Add `check_phase1`: `assert_no_rpm micro`, `assert_no_rpm starship` (template leftovers), Firefox still present (`assert_cmd firefox` — we keep Bazzite's browser, template's removal is reverted).
- [ ] **Step 2:** Move modules into `common.yml`, drop the template's micro/starship/Firefox-removal/Loupe entries; `recipe.yml` = name, description, base, `modules: [ { from-file: common.yml } ]`.
- [ ] **Step 3:** Push; CI green. User: first `bootc switch` in VM (TESTING.md phase 1: boots, internet works, KDE desktop appears).
- [ ] **Step 4:** Commit `feat: clean base recipe`.

### Task 2: Talking (Discord + mic)

**Files:** Modify `recipes/common.yml`.

- [ ] **Step 1:** `check_phase2`: `assert_grep dev.vencord.Vesktop` and `com.discordapp.Discord` in the image's default-flatpaks list (find its path under `/usr/share/bluebuild/` in the phase-1 image and record it in the test); `assert_cmd pw-cli` (PipeWire present).
- [ ] **Step 2:** Add both IDs to `default-flatpaks@v1` → `system.install`, `notify: true`.
- [ ] **Step 3:** CI green. Manual: Discord call with mic (VirtualBox: Devices → Audio → enable input); Vesktop screen share with sound.
- [ ] **Step 4:** Commit `feat: discord and vesktop`.

### Task 3: Cloud gaming

**Files:** Modify `recipes/common.yml`. Create `files/system/usr/share/applications/mountain-geforcenow.desktop`, `mountain-xboxcloud.desktop`, `mountain-boosteroid.desktop`.

- [ ] **Step 1:** `check_phase3`: three `.desktop` files exist; each `Exec=` contains `flatpak run com.microsoft.Edge --app=<exact URL from Global Constraints>`; `desktop-file-validate` passes on each; Edge ID in flatpak list.
- [ ] **Step 2:** Add `com.microsoft.Edge` to flatpaks; write the three launchers (`Categories=Game;`).
- [ ] **Step 3:** CI green. Manual: each launcher opens and reaches the login page. Hardware video decoding is tested only in Task 12 (real PC) — VM can't.
- [ ] **Step 4:** Commit `feat: cloud gaming launchers`.

### Task 4: Coding

**Files:** Modify `recipes/common.yml`. Create `files/system/etc/skel/Projects/.keep`.

- [ ] **Step 1:** `check_phase4`: `assert_cmd code`, `assert_cmd python3`, `python3 -c 'import sys; assert sys.version_info >= (3,12)'`, `assert_cmd git`, `assert_cmd pip3`, `assert_file /etc/skel/Projects/.keep`.
- [ ] **Step 2:** `rpm-ostree` module: repo URL from constraints; install `code`, `python3`, `python3-pip`, `git`.
- [ ] **Step 3:** CI green. Manual: VS Code opens, `hello.py` in `~/Projects` prints `hello`.
- [ ] **Step 4:** Commit `feat: coding tools`.

### Task 5: Microsoft alternatives

- [ ] **Step 1:** `check_phase5`: `org.onlyoffice.desktopeditors` in flatpak list.
- [ ] **Step 2:** Add the ID. (Edge already covers Microsoft web apps: Outlook, Teams, OneDrive.)
- [ ] **Step 3:** CI green. Manual: open a .docx, .xlsx, .pptx sample.
- [ ] **Step 4:** Commit `feat: onlyoffice`.

### Task 6: Gaming

- [ ] **Step 1:** `check_phase6`: `assert_cmd steam`, `assert_cmd gamemoderun`, Heroic ID in flatpak list.
- [ ] **Step 2:** Add `com.heroicgameslauncher.hgl`. Steam/Proton/gamemode come from Bazzite — do not reinstall.
- [ ] **Step 3:** CI green. Manual: install a free Steam game, it launches. Squad anti-cheat status: check protondb.com, note result in TESTING.md.
- [ ] **Step 4:** Commit `feat: heroic launcher`.

### Task 7: Make it light (highest risk — research first)

**Files:** Create `files/system/usr/lib/sysctl.d/90-mountain.conf`, systemd drop-ins under `files/system/usr/lib/systemd/system/<unit>.d/`.

- [ ] **Step 1 (research):** In the phase-6 VM run `systemctl list-unit-files --state=enabled`, `systemd-analyze blame | head -30`, `free -m`. Record baseline RAM in TESTING.md. Search Bazzite docs/GitHub for each candidate service before disabling — only disable services Bazzite documents as optional.
- [ ] **Step 2:** `check_phase7`: sysctl file contains `net.core.default_qdisc = fq` and `net.ipv4.tcp_congestion_control = bbr`; the update timer drop-in sets `OnCalendar=weekly`; each disabled service in the list is masked/disabled in the image.
- [ ] **Step 3:** Write sysctl file, update-timer drop-in (find the real Bazzite update timer name in step 1), disable chosen services via `systemd` module `disabled:`.
- [ ] **Step 4:** CI green. Manual: reboot 3×, `free -m` ≤ 1.5 GB used, internet + audio + Bluetooth still work.
- [ ] **Step 5:** Commit `perf: lighter defaults`.

### Task 8: Stability soak (no new features)

- [ ] **Step 1:** User uses the VM normally 2–3 days; 5 cold reboots; one boot with network disabled (Review Focus 1).
- [ ] **Step 2:** `journalctl -p err -b` after each boot — any new error is fixed in its owning task's files before continuing.
- [ ] **Step 3:** Merge `mountain-phases` → `main` (first public "latest"). Commit/tag `v0.1`.

### Task 9: NVIDIA auto-switch

**Files:** Create `recipes/recipe-nvidia.yml`, `files/system/usr/libexec/mountain-gpu-check`, `files/system/usr/lib/systemd/system/mountain-gpu-check.service`. Modify `build.yml` matrix, `common.yml` (`systemd` enable).

**Interfaces:** `mountain-gpu-check [--dry-run]` reads `/usr/share/mountain/config`; NVIDIA hardware = `lspci -nn | grep -i '\[10de:'`; NVIDIA image = `command -v nvidia-smi`. Mismatch → `bootc switch --enforce-container-sigpolicy <other image>:latest` and touch `/var/lib/mountain/gpu-switched`; if that file exists and matches the target, do nothing.

- [ ] **Step 1:** `check_phase9`: script exists, executable; with `PATH` pointing to a fake `lspci` printing an NVIDIA ID and `--dry-run`, first run prints `would switch to ...mountain-nvidia`, second run prints `already switched` (Review Focus 4).
- [ ] **Step 2:** Implement script + service (`Type=oneshot`, `After=network-online.target`, `Wants=network-online.target`); add `recipe-nvidia.yml` to matrix.
- [ ] **Step 3:** CI green for both images. Real hardware test happens in Task 12.
- [ ] **Step 4:** Commit `feat: nvidia auto-switch`.

### Task 10: Look and name

**Files:** Create `files/scripts/branding.sh`, wallpaper/logo under `files/system/usr/share/mountain/`, KDE defaults under `files/system/etc/xdg/`.

- [ ] **Step 1:** `check_phase10`: `/etc/os-release` (or `/usr/lib/os-release`) `PRETTY_NAME` starts with value of `MOUNTAIN_NAME`; `grep -rl "Mountain" /usr/share/applications /etc/xdg` returns nothing hard-coded except via config (Review Focus 5).
- [ ] **Step 2:** `branding.sh` sources the config and edits only `PRETTY_NAME` (Bazzite tools read `ID`/`NAME` — leave those). User picks wallpaper/theme; set as KDE defaults.
- [ ] **Step 3:** CI green; manual look check. Commit `feat: mountain branding`.

**After Task 10 (separate plans):** 11 own ISO installer, 12 real-PC USB test (Wi-Fi, mic, NVIDIA, Squad, cloud gaming with hardware decode).
