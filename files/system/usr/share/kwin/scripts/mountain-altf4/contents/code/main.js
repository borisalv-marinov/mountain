// Alt+F4 like Windows: close the active window; on the desktop (no normal window active) ask to shut down.
registerShortcut("WindowsAltF4", "Close window, or shut down from the desktop", "Alt+F4", function () {
    const w = workspace.activeWindow;
    if (w && w.normalWindow && !w.desktopWindow) {
        w.closeWindow();
    } else {
        callDBus("org.kde.LogoutPrompt", "/LogoutPrompt", "org.kde.LogoutPrompt", "promptShutDown");
    }
});
