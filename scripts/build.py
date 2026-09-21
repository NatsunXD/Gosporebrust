"""Build and inspect the GoPredator v1.2 branch package."""
import json
import os
from pathlib import Path
import struct
import subprocess
import sys

sys.dont_write_bytecode = True

from archive import ARCHIVE, EXE_SHA, GAME_DLL_SHA, GAME, LUA, TYPE, make_archive, resource_hash, sha
from module import build_module
from package import package_release

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / 'build'
SOURCE = ROOT / 'src'
TESTS = ROOT / 'tests'
RESOURCE = 'mods/natsun/gopredator'
IMPLEMENTATION_RESOURCE = RESOURCE + '_impl'
REVISION = 'planet-scope-go-predator-planet-3'
GUID = 'eefcedc1-ebd4-4662-91d6-14ed32f8133b'


def run(args, **kwargs):
    result = subprocess.run([str(a) for a in args], capture_output=True, text=True, **kwargs)
    if result.returncode:
        raise RuntimeError(result.stdout + result.stderr)
    return result.stdout


def inspect_archive(data):
    magic, version, count = struct.unpack_from('<III', data)
    if (magic, version) != (0xF0000011, 1):
        raise ValueError('Unsupported archive header')
    resources = []
    for index in range(count):
        entry = struct.unpack_from('<7Q6I', data, 104 + index * 80)
        offset, size = entry[2], entry[7]
        if offset % 16 or offset + size > len(data):
            raise ValueError('Archive resource is misaligned or out of range')
        if struct.unpack_from('<II', data, offset) != (size - 8, 2):
            raise ValueError('Archive resource is not a Lua resource')
        resources.append({'name': entry[0], 'type': entry[1], 'offset': offset,
                          'size': size, 'index': entry[12]})
    return {'num_files': count, 'resources': resources}


def main():
    BUILD.mkdir(exist_ok=True)
    for relative, expected in [('bin/helldivers2.exe', EXE_SHA), ('data/game/game.dll', GAME_DLL_SHA)]:
        if sha((GAME / relative).read_bytes()) != expected:
            raise ValueError('Unsupported game build: ' + relative)
    if not LUA.is_file():
        raise FileNotFoundError('LuaJIT not found; set HD2_LUAJIT to a pinned luajit.exe')
    build = BUILD / REVISION
    resources = build_module(ROOT, build, RESOURCE, REVISION)
    env = dict(os.environ, LUA_PATH=str(LUA.parent / '?.lua') + ';;')
    tests = run([LUA, TESTS / 'test_data.lua', SOURCE, build], env=env)
    (build / 'offline-tests.txt').write_text(tests, encoding='utf-8', newline='\n')
    data = build / 'data'
    data.mkdir(exist_ok=True)
    archive = make_archive(resources)
    (data / ARCHIVE).write_bytes(archive)
    for suffix in ('.stream', '.gpu_resources'):
        (data / (ARCHIVE + suffix)).write_bytes(b'')
    inspection = inspect_archive(archive)
    (build / 'archive-inspection.json').write_text(json.dumps(inspection, indent=2) + '\n', encoding='utf-8')
    expected = {resource_hash(RESOURCE), resource_hash(IMPLEMENTATION_RESOURCE)}
    actual = {item['name'] for item in inspection['resources']}
    if inspection['num_files'] != 2 or actual != expected or any(item['type'] != TYPE for item in inspection['resources']):
        raise ValueError('Archive must contain exactly the discovery and implementation resources')
    files = {f'data/{ARCHIVE}{suffix}': f'build/{REVISION}/data/{ARCHIVE}{suffix}'
             for suffix in ('', '.stream', '.gpu_resources')}
    report = {
        'name': 'GoPredator', 'slug': 'GoPredator', 'version': '1.2', 'guid': GUID,
        'revision': REVISION,
        'description': "Adds Predator Variant definitions 1243 and 1245 only to Terminid missions on planet 3 (Widow's Harbor), unlocks planet selection, and prepares local planet 3 task rows from neutral planet records. Mutually exclusive with Gosporebrust. Requires Bingus Shared Loader v15 or newer.",
        'game_exe_sha256': EXE_SHA, 'game_dll_sha256': GAME_DLL_SHA,
        'deployment_files': files,
        'files': {path: sha((ROOT / path).read_bytes()) for path in files.values()},
        'data_change': {
            'modifier_definition_ids': [1243, 1245], 'resolved_tag_ids': 'runtime',
            'campaign_tag_hash_rva': '0x1F38C90', 'modifier_definitions_rva': '0x277FDD0',
            'global_modifier_table_rva': '0x2770628', 'global_row_size': 356,
            'global_row_count': 32, 'global_scope': 0, 'target_planets': [3],
            'planet_names': {'3': "Widow's Harbor"},
            'filter_faction': 2, 'terminid_faction': 2,
            'modifier_entry_type': 17, 'max_entries_per_row': 5,
            'write_target': 'MEM_PRIVATE/PAGE_READWRITE global campaign modifier table',
            'idempotent': True, 'executable_code_writes': 0,
            'queue_or_population_counter_writes': False, 'runtime_verified': False,
            'planet_availability_mutation': True,
            'planet_availability_scope': 'planet 3 dynamic record availability field only',
            'task_entry_mutation': True,
            'active_planet_mutation': False,
            'active_planet_trigger': 'active_or_hovered_planet_3',
            'task_entry_copy': {
                'source_planet': None, 'target_planet': 3,
                'table_offset': 1012352, 'row_stride': 92,
                'planet_field_offset': 16, 'valid_field_offset': 52,
                'operation_field_offset': 24,
                'template_policy': 'neutral_planet_only_excludes_268',
            },
            'dynamic_access_mutation': {
                'planet': 3,
                'available_offset': 48, 'available_before': 0, 'available_after': 1,
                'evidence': 'same build-specific dynamic planet record layout as the tested base variant; exact GoPredator ZIP requires live verification',
            },
            'dynamic_faction_mutation': {
                'planet': 3, 'before': 1, 'after': 2,
                'board_pointer_rva': '0x277FF28', 'campaign_offset': 1053752,
                'record_stride': 304, 'record_offset': 286752, 'field_offset': 36,
                'scope': 'planet dynamic record only',
            },
        },
        'continuous_update_hook': True, 'shutdown_hook': False,
        'loader_integration': {
            'minimum_loader_version': 15, 'api': 1,
            'archive_name': ARCHIVE,
            'discovery_entry': RESOURCE, 'implementation_resource': IMPLEMENTATION_RESOURCE,
            'legacy_registry_compatible': True,
        },
    }
    report['requires'] = [{'name': 'Bingus Shared Loader', 'guid': '612eaf70-d682-43c7-9efd-16dcc695f977',
                           'api': 1, 'minimum_version': 15}]
    sources = (list(SOURCE.glob('*.lua')) + list(TESTS.glob('*.lua'))
               + list(TESTS.glob('*.py')) + list((ROOT / 'scripts').glob('*.py')))
    report['source_sha256'] = {
        path.relative_to(ROOT).as_posix(): sha(path.read_bytes()) for path in sources
    }
    release = package_release(ROOT, build, report)
    package_tests = run([sys.executable, TESTS / 'test_package.py', release])
    (build / 'package-tests.txt').write_text(package_tests, encoding='utf-8', newline='\n')
    report['package_tests'] = package_tests.strip().splitlines()
    report['release'] = {'path': Path(os.path.relpath(release, ROOT)).as_posix(), 'sha256': sha(release.read_bytes())}
    (BUILD / 'build-report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(tests.strip())
    print(package_tests.strip())
    print('Built ' + release.name + '; runtime verification remains pending.')


if __name__ == '__main__':
    main()
