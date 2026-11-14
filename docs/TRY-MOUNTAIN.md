# Try Mountain in your browser

You can use the Mountain desktop from any web browser, with nothing to install.

1. Open https://github.com/borisalv-marinov/mountain/actions
2. Click **Try Mountain** in the left list.
3. Click **Run workflow** (grey button, right side), then the green **Run workflow** button.
   (Optional: change "minutes" to choose how long it stays open. Default is 4 hours, the most is 5.)
4. Wait about 45 minutes. Click the new run, and when the **Summary** shows a line starting with "Open https://...", click that link (it ends in `/mountain.html`). The link only appears once the desktop is ready, so it can take a little longer to show up.
5. Press Connect if asked, and enter the password from your Mountain notes file (only the first 8 characters count).
6. Mountain starts on its lock screen (clock and date). Click or press a key, and it says **Hello, Mountain**.
   Type the desktop password `123` and press Enter. The same password unlocks the screen after Win+L and is the admin password.
   The very first start can take a few more minutes.

Or just ask Claude to start it for you.

## What works and what does not

- Works: the desktop, apps, browsing, the keyboard and mouse.
- Copy and paste: use the small **Paste** button at the top right. Paste your text in its box and press **Send to Mountain**; it is put on the desktop clipboard and also typed in, so it works even if the clipboard link fails. Text you copy inside Mountain shows up in the same box (press **Copy** to take it to your own computer).
- No sound.
- No graphics card (games and 3D will be slow or not run).
- Nothing is saved. When the time is up, everything is wiped. Copy out anything you want to keep first.
- The link changes every time and only works while the run is going.
- Sharpness: the page asks Mountain to use your browser window's exact size, so nothing is stretched, and the picture is sent without lossy compression. What can still look softer than a real PC is only the remote view: if Mountain can't match your window (very small windows, or while you resize), the browser scales the picture, which blurs text. Use the browser full screen (F11) for the sharpest picture.

## New in v5.1 — what to try

1. Quick settings (click the network/volume icons next to the clock): the **brightness** slider is there (greyed out in this VM, which has no screen backlight).
2. Open photos, PDFs and folders in File Explorer: it should feel quick. The sidebar and status bar no longer cut words, and the tab bar only shows with two or more tabs (Ctrl+T).
3. **Ctrl+Shift+Esc** opens **Task Manager**: Processes, Performance, App history, Startup apps, Users, Details, Services.
4. Start menu → **Security**: the status cards. Click **Scan now** (it downloads virus definitions first, a few minutes).
5. File Explorer → **Previous versions**: hourly copies of your files (the first appears 10 minutes after start).
6. Settings → Updates → **Go back to the previous version** (this fresh VM has no older version to go back to).

## New in v3 — what to try

1. The mouse: it should follow your hand now (the pointer is drawn by your browser).
2. Click the Mountain logo (bottom left of the taskbar): pinned apps, "All Applications", search. Type `settings` and press Enter.
3. Double-click **This PC** on the desktop: File Explorer with Home, Desktop, Documents, Downloads, Pictures, Music, Videos, Recycle Bin and a Windows 11 style bar (New, cut/copy/paste/rename/delete, Sort, View, Filter).
4. Open a photo, a PDF and a text file from File Explorer (double-click). Drag a file onto a folder and pick **Move Here**.
5. Desktop folders (Cloud Gaming, Games, AI, …): double-click to open. GeForce NOW / Xbox Cloud / Boosteroid open in Edge (slow without a graphics card here).
6. AI folder: click Claude Code, Codex, Gemini or Copilot. The first click installs it (about a minute), then it opens.
7. Start menu → **Top Bar On/Off** hides or shows the bar at the top.
8. No "KDE Wallet" pop-ups, no low-disk warning.
