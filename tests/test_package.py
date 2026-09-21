"""Verify the finished GoPredator release ZIP independently."""
import hashlib
import json
from pathlib import Path
import struct
import sys
import tempfile
import zipfile


def main():
    archive_name = '9ba626afa44a3aa3.patch_0'
    package_path = Path(sys.argv[1])
    with zipfile.ZipFile(package_path) as package:
        payloads = {name: package.read(name) for name in package.namelist()}
        expected = {f'data/{archive_name}{suffix}' for suffix in ('', '.stream', '.gpu_resources')}
        expected |= {'manifest.json', 'GoPredator-manifest.json', 'GoPredator-README.txt'}
        assert set(payloads) == expected and len(package.namelist()) == len(expected)
        assert not any(name.lower().endswith(('.dll', '.exe', '.lua', '.ps1')) for name in payloads)

        manager = json.loads(payloads['manifest.json'])
        provenance = json.loads(payloads['GoPredator-manifest.json'])
        assert manager['Version'] == 1
        assert manager['Guid'] == 'eefcedc1-ebd4-4662-91d6-14ed32f8133b'
        assert manager['Name'] == 'GoPredator - v2.0'
        assert manager['Options'] == [{
            'Name': 'GoPredator - v2.0',
            'Description': manager['Description'],
            'Include': ['data'],
        }]
        assert provenance['revision'] == 'planet-scope-go-predator-planet-125-v2'
        assert provenance['display_version'] == 'v2.0'
        assert provenance['steam_build'] == 24826606
        assert provenance['exe_version'] == '1.8.45317.0'
        assert provenance['runtime_verified'] is False
        assert provenance['requires'] == [{
            'name': 'Bingus Shared Loader',
            'guid': '612eaf70-d682-43c7-9efd-16dcc695f977',
            'api': 1,
            'minimum_version': 15,
        }]
        assert provenance['loader_integration'] == {
            'minimum_loader_version': 15,
            'api': 1,
            'archive_name': '9ba626afa44a3aa3.patch_0',
            'discovery_entry': 'mods/natsun/gopredator',
            'implementation_resource': 'mods/natsun/gopredator_impl',
            'legacy_registry_compatible': True,
        }
        change = provenance['data_change']
        assert change['modifier_definition_ids'] == [1243, 1245]
        assert change['resolved_tag_ids'] == 'runtime'
        assert change['terminid_faction'] == 2
        assert change['global_scope'] == 0
        assert change['target_planets'] == [125]
        assert change['planet_names'] == {'125': 'Fenrir III'}
        assert change['filter_faction'] == 2
        assert change['executable_code_writes'] == 0
        assert change['queue_or_population_counter_writes'] is False
        assert change['planet_availability_mutation'] is True
        assert change['task_entry_mutation'] is True
        assert change['active_planet_mutation'] is False
        assert change['active_planet_trigger'] == 'active_or_hovered_planet_125'
        assert change['task_entry_copy']['template_policy'] == 'neutral_planet_only_excludes_268'
        assert change['task_entry_copy'] == {
            'source_planet': None, 'target_planet': 125, 'table_offset': 1012352,
            'row_stride': 92, 'planet_field_offset': 16, 'valid_field_offset': 52,
            'operation_field_offset': 24,
            'template_policy': 'neutral_planet_only_excludes_268',
        }
        assert change['dynamic_faction_mutation'] == {
            'planet': 125, 'before': 1, 'after': 2,
            'board_pointer_rva': '0x277FF28', 'campaign_offset': 1053752,
            'record_stride': 304, 'record_offset': 286752, 'field_offset': 36,
            'scope': 'planet dynamic record only',
        }
        for name, digest in provenance['files'].items():
            assert hashlib.sha256(payloads[name]).hexdigest().upper() == digest

        sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
        from archive import resource_hash
        archive = payloads['data/' + archive_name]
        assert struct.unpack_from('<III', archive) == (0xF0000011, 1, 2)
        entry_name = 'mods/natsun/gopredator'
        implementation_name = entry_name + '_impl'
        entries = [struct.unpack_from('<7Q6I', archive, 104 + index * 80) for index in range(2)]
        assert {item[0] for item in entries} == {resource_hash(entry_name), resource_hash(implementation_name)}
        resources = {}
        for index, item in enumerate(entries):
            offset, size = item[2], item[7]
            assert item[1] == 0xA14E8DFA2CD117E2 and item[12] == index
            assert offset % 16 == 0 and offset + size <= len(archive)
            assert struct.unpack_from('<II', archive, offset) == (size - 8, 2)
            resources[item[0]] = archive[offset + 8:offset + size]
        declaration = ('-- HD2-Addon: ' + entry_name + '\n').encode('ascii')
        expected_entry = declaration + ("return require('" + implementation_name + "')\n").encode('ascii')
        assert resources[resource_hash(entry_name)] == expected_entry
        assert len(declaration) <= 256 and not expected_entry.startswith(b'\xef\xbb\xbf')
        assert resources[resource_hash(implementation_name)].startswith(b'\x1bLJ\x02\x02')
        assert payloads['data/' + archive_name + '.stream'] == b''
        assert payloads['data/' + archive_name + '.gpu_resources'] == b''

        forbidden = (b'virtualprotect', b'flushinstructioncache', b'createremotethread',
                     b'loadlibrary', b'hd2_native_stick.dll', b'asset-key')
        for data in payloads.values():
            lowered = data.lower()
            assert b'users\\' not in lowered and b'users/' not in lowered
            assert all(token not in lowered for token in forbidden)
        assert b'mods/natsun/gosporebrust' not in payloads['data/' + archive_name]
        assert b'mods/natsun/gopredator' in payloads['data/' + archive_name]
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / 'Unrelated install location'
            package.extractall(destination)
            assert all((destination / name).read_bytes() == data for name, data in payloads.items())

    print('PASS: exact ZIP allowlist, V1 manager manifest, provenance and SHA-256 digests')
    print('PASS: Loader v15 plaintext declaration is hash-matched and forwards to LuaJIT bytecode')
    print('PASS: archive bounds, alignment, sidecars, privacy scan and relocation')
    print('3 package inspection groups passed; runtime verification remains false.')


if __name__ == '__main__':
    main()
