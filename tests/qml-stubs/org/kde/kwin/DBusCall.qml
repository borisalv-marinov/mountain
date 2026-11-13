import QtQuick
import org.kde.kwin
QtObject {
    id: self
    property string service
    property string path
    property string dbusInterface
    property string method
    property var arguments: []
    signal finished(var returnValue)
    signal failed()
    function call() {
        if (method === "getClipboardHistoryMenu") finished([["Mountain-clip-2", "Mountain-clip-1"]]);
        if (method === "setClipboardContents") Workspace.clipboard = self.arguments[0]; // self.: plain `arguments` is the JS function's own
    }
}
