#!/usr/bin/env bash
# KDE's own process lists (System Monitor > Processes, the Details tab): Windows names, MB/GB instead of MiB/GiB,
# and no kernel threads (Windows Task Manager never lists them); the Apps table (Processes page) gets MB/GB too.
# Plain QML in the face package, no KDE C++ changed.
# Fails loudly if KDE's file changes shape.
set -euo pipefail
f=/usr/share/ksysguard/sensorfaces/org.kde.ksysguard.processtable/contents/ui/ProcessTableView.qml
[[ -f $f ]] || { echo "process-table: $f not found"; exit 1; }
# the same names as Mountain's Task Manager (/usr/libexec/mountain-taskmanager)
names=$(sed -n "/^names='/,/'$/p" /usr/libexec/mountain-taskmanager | sed "1s/^names='//; \$s/'$//" | tr '\n' '|')
bgn=$(sed -n "/^bgnames='/,/'$/p" /usr/libexec/mountain-taskmanager | sed "1s/^bgnames='//; \$s/'$//" | tr '\n' '|')
[[ $names == *"plasmashell=Windows Explorer"* ]] || { echo "process-table: name list not found in mountain-taskmanager"; exit 1; }
python3 - "$f" "$names" "$bgn" <<'PY'
import json, sys
p, names, bgn = sys.argv[1:4]
m = dict(x.split('=', 1) for x in names.split('|') if '=' in x)
b = dict(x.split('=', 1) for x in bgn.split('|') if '=' in x)
s = open(p, encoding='utf-8').read()
pairs = [
    ('    property bool flatList\n',
     '    property bool flatList\n\n'
     '    // Mountain: Windows names and units (MB, not MiB), as Windows Task Manager\n'
     '    readonly property var mtNames: ' + json.dumps(m, ensure_ascii=False) + '\n'
     '    readonly property var mtBg: ' + json.dumps(b, ensure_ascii=False) + '\n'
     '    readonly property bool mtIsBg: (Qt.locale().uiLanguages[0] || Qt.locale().name).substring(0, 2) === "bg"\n'
     '    function mtName(n) { n = String(n ?? ""); n = mtNames[n] ?? mtNames[n.split(" ")[0]] ?? n; return mtIsBg ? (mtBg[n] ?? n) : n; }\n'
     '    function mtUnits(t) { return String(t ?? "").replace(/([0-9])\\s?([KMGT])i\\u200b?B/g, "$1 $2B"); }\n' # KDE writes "191.8 Mi<zero-width space>B"
     '    function mtKeep(row, parent) { // false for kernel threads: pid 2 (kthreadd) and its children\n'
     '        const c = processModel.ppidColumn, i = processModel.pidColumn;\n'
     '        if (i < 0) return true;\n'
     '        const v = col => Number(cacheModel.data(cacheModel.index(row, col, parent))); // the shown text, "2"\n'
     '        return v(i) !== 2 && (c < 0 || v(c) !== 2);\n'
     '    }\n'),
    # kernel threads (pid 2 and its children) out, between the cache and KDE's own filter
    ('        sourceModel: cacheModel\n',
     '        sourceModel: kthreads\n'),
    ('    Table.ComponentCacheProxyModel {\n',
     '    KItemModels.KSortFilterProxyModel { // Mountain: no kernel threads\n'
     '        id: kthreads\n'
     '        sourceModel: cacheModel\n'
     '    }\n\n'
     '    Table.ComponentCacheProxyModel {\n'),
    ('        property int pidColumn\n',
     '        property int pidColumn\n        property int ppidColumn: -1\n'),
    ('            "pid",\n', '            "pid",\n            "parentPid",\n'), # KDE's name for the parent pid
    ('            processModel.pidColumn = result.indexOf("pid")\n',
     '            processModel.pidColumn = result.indexOf("pid")\n            processModel.ppidColumn = result.indexOf("parentPid")\n'),
    ('            processModel.enabledAttributes = result\n',
     '            processModel.enabledAttributes = result\n'
     '            kthreads.filterRowCallback = (row, parent) => view.mtKeep(row, parent) // once the columns exist; a new callback re-filters the rows already there\n'),
    ('            Table.FirstCellDelegate {\n                id: delegate\n',
     '            Table.FirstCellDelegate {\n                id: delegate\n                text: view.mtName(model.display)\n'),
    ('        DelegateChoice { Table.TextCellDelegate{} }\n',
     '        DelegateChoice { roleValue: "text"; Table.TextCellDelegate { text: view.mtUnits(model.display) } }\n'
     '        DelegateChoice { Table.TextCellDelegate { text: view.mtUnits(model.display) } }\n'),
]
for old, new in pairs:
    assert s.count(old) == 1, f'ProcessTableView.qml: expected 1 of {old!r}, got {s.count(old)}'
    s = s.replace(old, new)
n = s.count('index = rowFilter.mapToSource(index)')
assert n == 2, f'ProcessTableView.qml: expected 2 rowFilter mappings, got {n}'
s = s.replace('index = rowFilter.mapToSource(index)', 'index = kthreads.mapToSource(rowFilter.mapToSource(index))')
open(p, 'w', encoding='utf-8', newline='').write(s)
PY
grep -q 'id: kthreads' "$f" && grep -q 'mtUnits' "$f"
a=/usr/share/ksysguard/sensorfaces/org.kde.ksysguard.applicationstable/contents/ui/ApplicationsTableView.qml
[[ -f $a ]] || { echo "process-table: $a not found"; exit 1; }
python3 - "$a" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
pairs = [
    ('    property var enabledColumns: []\n',
     '    property var enabledColumns: []\n\n'
     '    // Mountain: units MB/GB, not MiB/GiB (KDE writes "191.8 Mi<zero-width space>B")\n'
     '    function mtUnits(t) { return String(t ?? "").replace(/([0-9])\\s?([KMGT])i\\u200b?B/g, "$1 $2B"); }\n'),
    ('        DelegateChoice { Table.TextCellDelegate { } }\n',
     '        DelegateChoice { Table.TextCellDelegate { text: view.mtUnits(model.display) } }\n'),
]
for old, new in pairs:
    assert s.count(old) == 1, f'ApplicationsTableView.qml: expected 1 of {old!r}, got {s.count(old)}'
    s = s.replace(old, new)
open(p, 'w', encoding='utf-8', newline='').write(s)
PY
grep -q 'mtUnits(model.display)' "$a"
# Apps table: no "Background Services" row (those processes are in the Background processes list)
python3 - "$a" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding='utf-8').read()
old = '            if (pids.length == 0) {\n                return false\n            }\n'
assert s.count(old) == 1, f'ApplicationsTableView.qml: expected 1 pids check, got {s.count(old)}'
s = s.replace(old, old +
    '            // Mountain: no "Background Services" row\n'
    '            if (String(sourceModel.data(sourceModel.index(row, appModel.enabledAttributes.indexOf("menuId"), parent))) == "services") {\n'
    '                return false\n'
    '            }\n')
open(p, 'w', encoding='utf-8', newline='').write(s)
PY
grep -q 'no "Background Services" row' "$a"
# Line charts (Performance page): axis and legend units MB/GB; history fills from the right (KDE's FillFromEnd draws the
# first seconds at the left and zeros to the right, which looks like the graph dropping to 0)
l=/usr/share/ksysguard/sensorfaces/org.kde.ksysguard.linechart/contents/ui
[[ -f $l/FullRepresentation.qml && -f $l/LineChart.qml ]] || { echo "process-table: linechart face not found"; exit 1; }
python3 - "$l" <<'PY'
import sys
d = sys.argv[1]
def patch(name, pairs):
    p = d + '/' + name
    s = open(p, encoding='utf-8').read()
    for old, new in pairs:
        assert s.count(old) == 1, f'{name}: expected 1 of {old!r}, got {s.count(old)}'
        s = s.replace(old, new)
    open(p, 'w', encoding='utf-8', newline='').write(s)
patch('FullRepresentation.qml', [
    ('    id: root\n',
     '    id: root\n'
     '    function mtUnits(t) { return String(t ?? "").replace(/([0-9])\\s?([KMGT])i\\u200b?B/g, "$1 $2B"); } // Mountain: MB/GB, not MiB/GiB\n'),
    ('                    text: Formatter.Formatter.formatValueShowNull(ChartsControls.AxisLabels.label,\n'
     '                        compactRepresentation.sensorsModel.unit)\n',
     '                    text: root.mtUnits(Formatter.Formatter.formatValueShowNull(ChartsControls.AxisLabels.label,\n'
     '                        compactRepresentation.sensorsModel.unit))\n'),
    ('            sensorIds: root.showLegend ? root.controller.lowPrioritySensorIds : []\n',
     '            sensorIds: root.showLegend ? root.controller.lowPrioritySensorIds : []\n'
     '            formatValue: function(input, index) {\n'
     '                return root.mtUnits(Formatter.Formatter.formatValueShowNull(input,\n'
     '                    compactRepresentation.sensorsModel.headerData(index, Qt.Horizontal, Sensors.SensorDataModel.Unit)))\n'
     '            }\n'),
])
patch('LineChart.qml', [('Charts.HistoryProxySource.FillFromEnd', 'Charts.HistoryProxySource.FillFromStart')])
# Disk and Network idle at 0 B/s, so every axis label read 0 B/s: keep the axis at least 1 MB/s (disk) or 128 KB/s (network) tall.
# Guarded so a face without those names still loads; the check below fails the build if the range block was not found.
patch('LineChart.qml', [('yRange {',
    'yRange {\n'
    '            minimum: (typeof root === "undefined" || !root.controller) ? 0 : (String(root.controller.highPrioritySensorIds).indexOf("disk/") >= 0 ? 1000000 : (String(root.controller.highPrioritySensorIds).indexOf("network/") >= 0 ? 128000 : 0))\n')])
PY
grep -q 'highPrioritySensorIds).indexOf' "$l/LineChart.qml"
grep -q 'root.mtUnits(Formatter' "$l/FullRepresentation.qml" && grep -q FillFromStart "$l/LineChart.qml"
echo "process-table: patched $f"
