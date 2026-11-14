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
[[ $names == *"plasmashell=Windows Explorer"* ]] || { echo "process-table: name list not found in mountain-taskmanager"; exit 1; }
python3 - "$f" "$names" <<'PY'
import json, sys
p, names = sys.argv[1], sys.argv[2]
m = dict(x.split('=', 1) for x in names.split('|') if '=' in x)
s = open(p, encoding='utf-8').read()
pairs = [
    ('    property bool flatList\n',
     '    property bool flatList\n\n'
     '    // Mountain: Windows names and units (MB, not MiB), as Windows Task Manager\n'
     '    readonly property var mtNames: ' + json.dumps(m, ensure_ascii=False) + '\n'
     '    function mtName(n) { n = String(n ?? ""); return mtNames[n] ?? mtNames[n.split(" ")[0]] ?? n; }\n'
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
echo "process-table: patched $f"
