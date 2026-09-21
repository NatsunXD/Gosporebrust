local ffi = require('ffi')
local source, build = assert(arg[1]), assert(arg[2])
local patch = assert(loadfile(source .. '/gosporebrust.lua'))()

local count = 0
local function pass(message)
    count = count + 1
    print('PASS: ' .. message)
end

local function put_u32(address, value)
    ffi.cast('uint32_t *', address)[0] = value
end

local function get_u32(address)
    return tonumber(ffi.cast('uint32_t *', address)[0])
end

local function pointer_bytes(address)
    local value = ffi.new('void *[1]', address)
    return ffi.string(value, 8)
end

local game_storage = ffi.new('uint8_t[1]')
local game = ffi.cast('uint8_t *', game_storage)
local definitions_storage = ffi.new('uint8_t[?]', patch.definition_count_offset + 4)
local definitions = ffi.cast('uint8_t *', definitions_storage)
local board_storage = ffi.new('uint8_t[?]', math.max(
    patch.campaign_offset + patch.planet_dynamic_stride * 174 + patch.planet_dynamic_offset
        + patch.planet_dynamic_stride,
    patch.local_rows_offset + patch.local_rows_capacity * patch.local_row_stride,
    1548956 + 4))
local board = ffi.cast('uint8_t *', board_storage)
local campaign = board + patch.campaign_offset
local dynamic3 = campaign + patch.planet_dynamic_stride * patch.dynamic_faction_planet
    + patch.planet_dynamic_offset
local dynamic125 = campaign + patch.planet_dynamic_stride * 125 + patch.planet_dynamic_offset
local dynamic127 = campaign + patch.planet_dynamic_stride * 127 + patch.planet_dynamic_offset
local dynamic268 = campaign + patch.planet_dynamic_stride * 268 + patch.planet_dynamic_offset
local local_rows = board + patch.local_rows_offset
local local_rows_size = patch.local_rows_capacity * patch.local_row_stride
local globals_storage = ffi.new('uint8_t[?]', patch.global_rows * patch.global_row_size)
local globals = ffi.cast('uint8_t *', globals_storage)
local alternate_storage = ffi.new('uint8_t[?]', patch.global_rows * patch.global_row_size)
local alternate = ffi.cast('uint8_t *', alternate_storage)
local hashes_storage = ffi.new('uint8_t[?]', patch.tag_count * 4)
local hashes = ffi.cast('uint8_t *', hashes_storage)

local writes, fail_write_at, replace_after_write = 0, nil, nil
local owner_present, owner_replaced, writable = true, false, true
local api = {}

function api.distance(first, second)
    return tonumber(ffi.cast('intptr_t', first) - ffi.cast('intptr_t', second))
end

function api.pointer(bytes, offset)
    offset = offset or 0
    if not bytes or offset + 8 > #bytes then return nil end
    local value = ffi.new('uintptr_t[1]')
    ffi.copy(value, bytes:sub(offset + 1, offset + 8), 8)
    if value[0] < 0x10000 then return nil end
    return ffi.cast('uint8_t *', value[0])
end

function api.read(address, size)
    if api.distance(address, game + patch.globals_pointer_rva) == 0 then
        if not owner_present then return string.rep('\0', 8) end
        return pointer_bytes(owner_replaced and alternate or globals)
    end
    if api.distance(address, game + patch.definition_pointer_rva) == 0 then
        return pointer_bytes(definitions)
    end
    if api.distance(address, game + patch.board_pointer_rva) == 0 then
        return pointer_bytes(board)
    end
    if api.distance(address, game + patch.tag_hashes_rva) == 0 then
        return ffi.string(hashes, size)
    end
    return ffi.string(address, size)
end

function api.writable_data(address, size)
    return writable and ((api.distance(address, globals) == 0
        and size == patch.global_rows * patch.global_row_size)
        or (api.distance(address, dynamic3) == 0 and size == patch.planet_dynamic_stride)
        or (api.distance(address, local_rows) == 0 and size == local_rows_size)
        or (api.distance(address, board + 1548952) == 0 and size == 4)
        or (api.distance(address, board + 1548956) == 0 and size == 4))
end

function api.write(address, bytes)
    writes = writes + 1
    if fail_write_at and writes == fail_write_at then return false end
    ffi.copy(address, bytes, #bytes)
    if replace_after_write and writes == replace_after_write then owner_replaced = true end
    return true
end

local function reset()
    ffi.fill(definitions, patch.definition_count_offset + 4, 0)
    ffi.fill(board, patch.campaign_offset + patch.planet_dynamic_stride * 174
        + patch.planet_dynamic_offset + patch.planet_dynamic_stride, 0)
    ffi.fill(local_rows, local_rows_size, 0)
    ffi.fill(globals, patch.global_rows * patch.global_row_size, 0)
    ffi.fill(alternate, patch.global_rows * patch.global_row_size, 0)
    ffi.fill(hashes, patch.tag_count * 4, 0)
    put_u32(definitions, patch.modifier_definition_ids[1])
    put_u32(definitions + 4, 40)
    put_u32(definitions + 24, 13)
    put_u32(definitions + 28, 0xA3A3DB9F)
    put_u32(definitions + 52, patch.modifier_definition_ids[2])
    put_u32(definitions + 56, 40)
    put_u32(definitions + 76, 13)
    put_u32(definitions + 80, 0xB4B4ECAC)
    put_u32(definitions + patch.definition_count_offset, 2)
    put_u32(hashes + 9 * 4, 0xA3A3DB9F)
    put_u32(hashes + 10 * 4, 0xB4B4ECAC)
    put_u32(dynamic3 + patch.dynamic_faction_offset, patch.dynamic_faction_before)
    put_u32(dynamic125 + patch.dynamic_faction_offset, patch.dynamic_faction_before)
    put_u32(dynamic127 + patch.dynamic_faction_offset, 3)
    put_u32(dynamic268 + patch.dynamic_faction_offset, patch.terminid_faction)
    put_u32(dynamic3 + patch.access_state_offset, patch.access_state_before)
    put_u32(dynamic3 + patch.access_timer_offset, patch.access_timer_before)
    put_u32(dynamic3 + patch.access_available_offset, patch.access_available_before)
    writes, fail_write_at, replace_after_write = 0, nil, nil
    owner_present, owner_replaced, writable = true, false, true
end

local function set_active(planet)
    put_u32(board + 1548952, planet)
    put_u32(board + 1548956, planet)
end

local function set_local_row(index, planet, operation)
    local row = local_rows + index * patch.local_row_stride
    put_u32(row, index)
    put_u32(row + patch.local_row_planet_offset, planet)
    row[patch.local_row_valid_offset] = 1
    row[24] = operation
end

local function set_entry(row, slot, tag)
    local base = globals + row * patch.global_row_size + slot * patch.global_entry_stride
    base[patch.global_entry_type_offset] = patch.modifier_entry_type
    put_u32(base + patch.global_entry_tag_offset, tag)
end

local function set_row(row, total, scope, value, filter)
    local base = globals + row * patch.global_row_size
    put_u32(base + patch.global_total_offset, total)
    put_u32(base + patch.global_scope_offset, scope)
    put_u32(base + patch.global_value_offset, value)
    put_u32(base + patch.global_filter_offset, filter)
end

reset()
local ok, status, active = patch.apply(api, game)
assert(ok and active and status == 'gopredator_applied')
assert(globals[patch.global_entry_type_offset] == patch.modifier_entry_type)
assert(get_u32(globals + patch.global_entry_tag_offset) == 9)
assert(get_u32(globals + patch.global_total_offset) == 2)
assert(get_u32(globals + patch.global_scope_offset) == 0)
assert(get_u32(globals + patch.global_value_offset) == 3)
assert(get_u32(globals + patch.global_filter_offset) == patch.terminid_faction)
assert(get_u32(dynamic3 + patch.dynamic_faction_offset) == patch.dynamic_faction_after)
assert(get_u32(dynamic125 + patch.dynamic_faction_offset) == patch.dynamic_faction_before)
assert(get_u32(dynamic127 + patch.dynamic_faction_offset) == 3)
assert(get_u32(dynamic268 + patch.dynamic_faction_offset) == patch.terminid_faction)
assert(get_u32(globals + patch.global_total_offset) == 2)
assert(get_u32(globals + patch.global_entry_stride + patch.global_entry_tag_offset) == 10)
pass('definitions 1243 and 1245 resolve independently and both apply to planet 3')

local applied_writes = writes
ok, status, active = patch.apply(api, game)
assert(ok and active and status == 'gopredator_ready' and writes == applied_writes)
pass('repeated updates are idempotent')

reset()
set_active(268)
for index = 0, 2 do set_local_row(index, 268, 40 + index) end
ok, status, active = patch.apply(api, game)
assert(ok and active and status == 'gopredator_applied')
assert(get_u32(dynamic3 + patch.dynamic_faction_offset) == 2)
assert(get_u32(dynamic125 + patch.dynamic_faction_offset) == patch.dynamic_faction_before)
assert(get_u32(dynamic268 + patch.dynamic_faction_offset) == 2)
pass('only planet 3 dynamic faction changes from 1 to Terminid 2; planets 125 and 268 remain unchanged')

reset()
set_active(268)
for index = 0, 2 do set_local_row(index, 268, 40 + index) end
ok, status, active = patch.apply(api, game)
assert(ok and active and patch.detail:find('task_rows=idle', 1, true))
for index = 0, 2 do
    local row = local_rows + index * patch.local_row_stride
    assert(get_u32(row + patch.local_row_planet_offset) == 268)
    assert(row[24] == 40 + index)
end
assert(get_u32(board + 1548952) == 268)
pass('GoPredator leaves planet 268 task rows and active planet untouched')

reset()
set_active(3)
for index = 0, 2 do set_local_row(index, 42, 60 + index) end
ok, status, active = patch.apply(api, game)
assert(ok and active and status == 'gopredator_applied')
for index = 0, 2 do
    local source_row = local_rows + index * patch.local_row_stride
    local target_row = local_rows + (index + 3) * patch.local_row_stride
    assert(get_u32(source_row + patch.local_row_planet_offset) == 42)
    assert(get_u32(target_row + patch.local_row_planet_offset) == 3)
    assert(target_row[24] == 60 + index)
end
assert(patch.detail:find('task_rows=copy_neutral_42_to_3:3', 1, true))
pass('planet 3 receives task rows from a neutral non-268 template without changing the source')

reset()
put_u32(dynamic3 + patch.dynamic_faction_offset, patch.dynamic_faction_after)
ok, status, active = patch.apply(api, game)
assert(ok and active and status == 'gopredator_applied')
assert(get_u32(dynamic3 + patch.dynamic_faction_offset) == patch.dynamic_faction_after)
pass('an already-applied dynamic faction is idempotent')

reset()
put_u32(dynamic3 + patch.dynamic_faction_offset, 3)
ok, status, active = patch.apply(api, game)
assert(ok and not active and status == 'gopredator_waiting' and writes == 0)
assert(get_u32(dynamic3 + patch.dynamic_faction_offset) == 3)
pass('an unexpected dynamic faction value is never overwritten')

reset()
set_row(0, 1, 0, 3, patch.terminid_faction)
set_entry(0, 0, 11)
ok, status, active = patch.apply(api, game)
assert(ok and active and get_u32(globals + patch.global_total_offset) == 3)
assert(get_u32(globals + patch.global_entry_stride + patch.global_entry_tag_offset) == 9)
assert(get_u32(globals + patch.global_entry_tag_offset) == 11)
assert(get_u32(globals + 2 * patch.global_entry_stride + patch.global_entry_tag_offset) == 10)
pass('existing planet 3 rows are extended with both tags without changing entries')

reset()
set_row(0, 1, 0, 3, 0)
set_entry(0, 0, 11)
local global_before = ffi.string(globals, patch.global_row_size)
ok, status, active = patch.apply(api, game)
assert(ok and active and ffi.string(globals, patch.global_row_size) == global_before)
local second = globals + patch.global_row_size
assert(get_u32(second + patch.global_scope_offset) == 0)
assert(get_u32(second + patch.global_value_offset) == 3)
assert(get_u32(second + patch.global_filter_offset) == patch.terminid_faction)
assert(get_u32(second + patch.global_entry_tag_offset) == 9)
assert(get_u32(second + patch.global_total_offset) == 2)
assert(get_u32(second + patch.global_entry_stride + patch.global_entry_tag_offset) == 10)
pass('an unfiltered planet row is never broadened; filtered target rows are created separately')

reset()
set_row(0, patch.max_entries, 0, 3, patch.terminid_faction)
for slot = 0, patch.max_entries - 1 do set_entry(0, slot, slot + 1) end
ok, status, active = patch.apply(api, game)
second = globals + patch.global_row_size
assert(ok and active and get_u32(globals + patch.global_total_offset) == patch.max_entries)
assert(get_u32(second + patch.global_total_offset) == 2 and get_u32(second + patch.global_entry_tag_offset) == 9)
assert(get_u32(second + patch.global_entry_stride + patch.global_entry_tag_offset) == 10)
assert(get_u32(second + patch.global_value_offset) == 3 and get_u32(second + patch.global_filter_offset) == patch.terminid_faction)
pass('a full target row falls back to a new row for that planet')

reset()
set_row(0, 1, 0, 3, 0)
set_entry(0, 0, 9)
set_row(1, 1, 0, 268, patch.terminid_faction)
set_entry(1, 0, 9)
ok, status, active = patch.apply(api, game)
assert(ok and active and status == 'gopredator_applied' and writes >= 1
    and get_u32(dynamic3 + patch.dynamic_faction_offset) == patch.dynamic_faction_after)
pass('already effective target tags are detected while the planet 3 faction experiment applies once')

reset()
set_row(0, 1, 2, patch.terminid_faction, 0)
set_entry(0, 0, 11)
ok, status, active = patch.apply(api, game)
assert(ok and active)
assert(get_u32(globals + patch.global_total_offset) == 1)
assert(get_u32(globals + patch.global_entry_tag_offset) == 11)
pass('an unrelated Terminid faction row is preserved')

reset()
put_u32(definitions + 24, 99)
ok, status, active = patch.apply(api, game)
assert(ok and not active and status == 'gopredator_waiting' and writes == 0)
pass('an unexpected modifier definition fails closed')

reset()
writable = false
ok, status, active = patch.apply(api, game)
assert(ok and not active and status == 'gopredator_waiting' and writes == 0)
pass('non-private or non-writable campaign storage is rejected')

reset()
owner_present = false
ok, status, active = patch.apply(api, game)
assert(ok and not active and status == 'gopredator_waiting' and writes == 0)
pass('an unavailable campaign owner remains retryable and untouched')

reset()
fail_write_at = 6
ok, status, active = patch.apply(api, game)
assert(ok and not active and status == 'gopredator_waiting')
assert(ffi.string(globals, patch.global_row_size) == string.rep('\0', patch.global_row_size))
pass('a partial write failure rolls back fields already applied')


reset()
replace_after_write = 1
ok, status, active = patch.apply(api, game)
assert(ok and not active and status == 'gopredator_waiting')
assert(ffi.string(globals, patch.global_row_size) == string.rep('\0', patch.global_row_size))
pass('campaign owner replacement is detected and the stale row is rolled back')

local identity = {revision = 'fixture', exe_sha256 = 'exe', game_sha256 = 'game'}
local env = setmetatable({print = function() end, os = {getenv = function() end}}, {__index = _G})
env._G = env
env.update = function(_, marker) return 1, nil, marker end
local loader_chunk = assert(loadfile(source .. '/archive_loader.lua'))
setfenv(loader_chunk, env)
local install = loader_chunk()
setfenv(install, env)
local checks = 0
install(function()
    return {
        module = function(name) return name and 'game' or 'exe' end,
        module_hash = function(module) return module end,
    }
end, {detail = '', apply = function()
    checks = checks + 1
    return true, 'gopredator_ready', true
end}, identity)
local results = {env.update(0.1, 3)}
assert(results[1] == 1 and results[2] == nil and results[3] == 3)
assert(select('#', env.update(0.1, 4)) == 3 and checks == 2)
pass('loader update preserves nil-containing callback tuples')

local required, required_count
local entry_env = setmetatable({require = function(name)
    required, required_count = name, (required_count or 0) + 1
    return 'loaded'
end}, {__index = _G})
entry_env._G = entry_env
local entry = assert(loadfile(build .. '/entry.lua'))
setfenv(entry, entry_env)
assert(entry() == 'loaded')
assert(required == 'mods/natsun/gosporebrust_impl' and required_count == 1)
pass('Loader v15 discovery entry forwards exactly once')

print(count .. ' GoPredator checks passed; no executable code, queues or population counters were modified.')
