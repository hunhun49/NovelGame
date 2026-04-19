$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$python = Join-Path $root '.graphify_python'
if (Test-Path $python) {
    $py = Get-Content -Raw $python
} else {
    $py = Join-Path $root '..\.venv\Scripts\python.exe'
}
& $py (Join-Path $PSScriptRoot 'rebuild_wiki_graph.py')
