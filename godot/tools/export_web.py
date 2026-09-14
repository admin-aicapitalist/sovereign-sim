"""Export the browser game using installed templates or an explicit template folder.

Run from any directory. Do not run alongside another export of this project.
Only Python's standard library is required; Godot and matching export templates
must already be installed or downloaded.
"""
import argparse
import gzip
import json
import os
from pathlib import Path
import re
import shutil
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--godot', default=os.environ.get('GODOT_BIN', 'godot'))
parser.add_argument('--templates', type=Path, help='Folder containing web_nothreads_release.zip')
args = parser.parse_args()
project = Path(__file__).resolve().parents[1]
engine = shutil.which(args.godot)
if not engine:
    parser.error('Godot not found. Pass --godot /path/to/Godot or set GODOT_BIN.')
preset = project / 'export_presets.cfg'
original = preset.read_text()
configured = original
if args.templates:
    for flavor in ['debug', 'release']:
        template = (args.templates / f'web_nothreads_{flavor}.zip').resolve()
        if not template.is_file():
            parser.error(f'Missing template: {template}')
        configured = re.sub(rf'^custom_template/{flavor}=.*$',
                            lambda _: f'custom_template/{flavor}={json.dumps(str(template))}',
                            configured, flags=re.MULTILINE)
output = project / 'build/web'
output.mkdir(parents=True, exist_ok=True)
(project / 'build/.gdignore').touch()
try:
    preset.write_text(configured)
    result = subprocess.run([engine, '--headless', '--path', str(project), '--export-release', 'Web'],
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    print(result.stdout, end='')
    if result.returncode or re.search(r'SCRIPT ERROR|Parse Error|ERROR:', result.stdout):
        raise SystemExit('Godot export failed; see engine output above.')
finally:
    preset.write_text(original)
for required in ['index.html', 'index.js', 'index.wasm', 'index.pck']:
    if not (output / required).is_file():
        raise SystemExit(f'Export did not produce {required}')
files = []
for file in sorted(output.iterdir()):
    if file.is_file() and file.suffix in ['.html', '.js', '.wasm', '.pck', '.png']:
        data = file.read_bytes()
        compressed = gzip.compress(data, compresslevel=9, mtime=0)
        if file.suffix in ['.html', '.js', '.wasm', '.pck']:
            file.with_name(file.name + '.gz').write_bytes(compressed)
        files.append({'file': file.name, 'bytes': len(data), 'gzip_bytes': len(compressed)})
report = {'files': files, 'total_bytes': sum(f['bytes'] for f in files),
          'total_gzip_bytes': sum(f['gzip_bytes'] for f in files)}
(project / 'reports/download.json').write_text(json.dumps(report, indent=2) + '\n')
print(f"Web export ready: {output}\nGzip estimate: {report['total_gzip_bytes']/1_000_000:.2f} MB")
