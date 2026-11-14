"""Loads Mountain's KWin QML scripts with stand-ins for org.kde.kwin and presses their shortcut: any QML error fails.
Needs PySide6 (pip install pyside6). Usage: python tests/test-kwin-qml.py"""
import glob, os, sys
from PySide6.QtCore import QObject, QUrl, QTimer, Qt
from PySide6.QtTest import QTest
from PySide6.QtGui import QGuiApplication, QWindow
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import qInstallMessageHandler

here = os.path.dirname(os.path.abspath(__file__))
msgs = []
qInstallMessageHandler(lambda mode, ctx, msg: msgs.append(msg))
app = QGuiApplication(sys.argv)
rc = 0
for f in sorted(glob.glob(os.path.join(here, '..', 'files/system/usr/share/kwin/scripts/org.mountain.*/contents/ui/main.qml'))):
    name = f.split('scripts' + os.sep)[-1].split(os.sep)[0] if os.sep in f else f
    msgs.clear()
    eng = QQmlApplicationEngine()
    eng.addImportPath(os.path.join(here, 'qml-stubs'))
    eng.load(QUrl.fromLocalFile(os.path.abspath(f)))
    roots = eng.rootObjects()
    ok = bool(roots)
    if ok:
        root = roots[0]
        sc = root.findChild(QObject, 'shortcut')
        ok = sc is not None
        if ok:
            sc.activated.emit()
            seen = []
            def look():  # before quit(): since Qt 6.5 quit() closes every window
                seen.append(isinstance(root, QWindow) and root.isVisible()); app.quit()
            QTimer.singleShot(300, look); app.exec()
            ok = seen == [True]
            if ok and 'clipboard' in f:  # Down, Enter picks the second item, like the VM test
                QTest.keyClick(root, Qt.Key_Down); QTest.keyClick(root, Qt.Key_Return); app.processEvents()
                ws = eng.singletonInstance('org.kde.kwin', 'Workspace')
                got = ws.property('clipboard') if ws else None
                ok = got == 'Mountain-clip-1'
                if not ok: msgs.append('Down, Enter copied %r, not Mountain-clip-1' % got)
            if ok and 'snaplayouts' in f:  # Enter on the first zone: the window takes the left half
                QTest.keyClick(root, Qt.Key_Return); app.processEvents()
                ws = eng.singletonInstance('org.kde.kwin', 'Workspace')
                g = ws.property('activeWindow').toVariant()['frameGeometry'] if ws else None
                ok = g is not None and round(g.width()) == 640 and round(g.x()) == 0
                if not ok: msgs.append('Enter left the window at %r, not the left half' % (g,))
    errors = [m for m in msgs if 'mountain-flyout' not in m and 'QFontDatabase' not in m and 'no longer ships fonts' not in m]
    if errors: ok = False
    print(('ok: ' if ok else 'FAIL: ') + os.path.relpath(f, os.path.join(here, '..')) + ' opens on its shortcut')
    for m in msgs: print('   ', m)
    rc |= not ok
    for r in roots: r.deleteLater()
sys.exit(rc)
