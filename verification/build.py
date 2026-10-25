"""Offline validation and deterministic private packaging. No install/network writes."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'ZugZugFit'


def digest(data):
    return hashlib.sha256(data).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--lua', type=Path, default=ROOT.parent / 'PaladinRegen/.tools/lua-5.4.8/src/lua')
    parser.add_argument('--package', action='store_true')
    args = parser.parse_args()
    lua = args.lua.resolve()
    toc = (SOURCE / 'ZugZugFit.toc').read_text()
    version = re.search(r'^## Version: ([\w.-]+)$', toc, re.M)[1]
    assert '## SavedVariables: ZugZugFitDB' in toc and 'SavedVariablesPerCharacter' not in toc

    modules = [line.strip() for line in toc.splitlines() if line.strip() and not line.startswith('#')]
    assert modules == ['Core.lua', 'Model.lua', 'Guild.lua', 'Widgets.lua', 'Calendar.lua', 'UI.lua', 'Client.lua']
    assert set(modules) == {p.name for p in SOURCE.glob('*.lua')}
    assert f'ZZ.VERSION = "{version}"' in (SOURCE / 'Core.lua').read_text()
    paths = sorted(SOURCE.rglob('*'))
    assert not any(p.is_symlink() for p in paths)
    payload = {str(p.relative_to(SOURCE)): p.read_bytes() for p in paths if p.is_file()}
    output = []
    checks = [
        [str(lua), '-e', ';'.join(f'assert(loadfile("ZugZugFit/{name}"))' for name in modules)],
        [str(lua), 'verification/lint.lua'],
        [str(lua), 'tests/test_core.lua'],
        [str(lua), 'tests/test_model.lua'],
        [str(lua), 'tests/test_guild.lua'],
        [str(lua), 'tests/test_client.lua'],
        [str(lua), 'tests/test_legacy.lua'],
        [str(lua), 'tests/test_journey.lua'],
    ]
    for command in checks:
        result = subprocess.run(command, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        print(result.stdout, end='')
        output.append(result.stdout)
        if result.returncode:
            raise SystemExit(result.returncode)
    assert all((SOURCE / name).read_bytes() == data for name, data in payload.items()), 'Source changed during checks'
    report = {
        'version': version, 'interfaces': {'Forever': '16001', 'Era': '11508, 11509', 'Retail': '120105'},
        'scope': 'account-wide solo routines and opt-in guild snapshots',
        'in_game_validated': False, 'installed': False,
        'evidence': 'Lua behavior and explicit mock WoW UI/client APIs; no native rendering validation',
        'files': {name: digest(data) for name, data in payload.items()},
    }
    if args.package:
        folder = ROOT / 'dist'
        folder.mkdir(exist_ok=True)
        report['archives'] = {}
        for flavor, interface in report['interfaces'].items():
            archive = folder / f'ZugZugFit-{version}-{flavor}.zip'
            flavor_payload = dict(payload)
            flavor_payload['ZugZugFit.toc'] = re.sub(r'^## Interface: .*$', '## Interface: ' + interface, toc, flags=re.M).encode()
            if flavor == 'Retail':
                flavor_payload['README.txt'] += b'\nRetail test package: interface 120105, prepared for installed 12.1.5.70575.\nRetail in-game acceptance is pending; use /zzf and /zzf selftest.\n'
            members = {'ZugZugFit/' + name: data for name, data in flavor_payload.items()}
            if not archive.exists():
                with zipfile.ZipFile(archive, 'x', zipfile.ZIP_DEFLATED) as z:
                    for name, data in members.items():
                        info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
                        info.compress_type = zipfile.ZIP_DEFLATED
                        info.external_attr = 0o100644 << 16
                        z.writestr(info, data)
            with zipfile.ZipFile(archive) as z:
                assert z.testzip() is None
                assert set(z.namelist()) == set(members)
                for name, data in members.items():
                    assert z.read(name) == data, 'Existing release differs; use a new version'
            report['archives'][flavor] = {
                'path': str(archive.relative_to(ROOT)), 'sha256': digest(archive.read_bytes()),
                'files': {name: digest(data) for name, data in members.items()},
            }
            print('Verified package:', archive)
    (ROOT / 'verification/results.txt').write_text(''.join(output))
    (ROOT / 'verification/report.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Offline validation complete; in-game acceptance pending.')


if __name__ == '__main__':
    main()
