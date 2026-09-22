local ffi
local patch = {
    revision = 'planet-scope-v4-planet-127-only',
    task_mutation_enabled = true,
    modifier_definition_id = 1244,
    removed_modifier_definition_id = 1241,
    terminid_faction = 2,
    target_planets = {127},
    tag_count = 32,
    definition_stride = 52,
    definition_count_offset = 53248,
    definition_pointer_rva = 0x347cd98,
    tag_hashes_rva = 0x21e18e0,
    globals_pointer_rva = 0x346d518,
    global_rows = 32,
    global_row_size = 356,
    global_total_offset = 80,
    global_scope_offset = 84,
    global_value_offset = 88,
    global_filter_offset = 92,
    global_entry_stride = 16,
    global_entry_type_offset = 0,
    global_entry_tag_offset = 4,
    max_entries = 5,
    modifier_entry_type = 17,
    board_pointer_rva = 0x347cee8,
    campaign_offset = 1053752,
    planet_dynamic_stride = 304,
    planet_dynamic_offset = 286752,
    dynamic_faction_offset = 36,
    dynamic_faction_planet = 127,
    dynamic_faction_before = 1,
    dynamic_faction_after = 2,
    -- Campaign access fields observed by comparing modifier unlock standby
    -- with a clean map snapshot on the supported build.
    access_state_offset = 28,
    access_state_before = 17,
    access_state_intermediate = 9,
    access_state_after = 5,
    access_timer_offset = 44,
    access_timer_before = 1077004060,
    access_timer_after = 0,
    access_available_offset = 48,
    access_available_before = 0,
    access_available_after = 1,
    local_rows_offset = 1012352,
    local_rows_capacity = 110,
    local_row_stride = 92,
    local_row_planet_offset = 16,
    local_row_valid_offset = 52,
    task_source_planet = 268,
    task_target_planet = 127,
    active_planet_offset = 1548952,
    hovered_planet_offset = 1548956,
}
patch.detail = ''
local task_cache = {rows = nil, slots = nil, owner = nil, applied = nil}

local ZERO_16 = string.rep('\0', 16)
local ZERO_ROW = string.rep('\0', patch.global_row_size)

local function ensure_ffi()
    ffi = ffi or require('ffi')
    return ffi
end

local function u32(bytes, offset)
    if not bytes or offset < 0 or offset + 4 > #bytes then return nil end
    local a, b, c, d = bytes:byte(offset + 1, offset + 4)
    return a + b * 256 + c * 65536 + d * 16777216
end

local function pack_u32(value)
    ensure_ffi()
    return ffi.string(ffi.new('uint32_t[1]', value), 4)
end

local function pack_u16(value)
    ensure_ffi()
    return ffi.string(ffi.new('uint16_t[1]', value), 2)
end

local function pack_entry(tag)
    return string.char(patch.modifier_entry_type, 0, 0, 0) .. pack_u32(tag) .. string.rep('\0', 8)
end

local function ptr(api, address)
    local bytes = assert(api.read(address, 8), 'pointer read failed')
    return assert(api.pointer(bytes), 'null or invalid pointer')
end

local function same_pointer(api, first, second)
    return first and second and api.distance(first, second) == 0
end

local function hex_address(value)
    ensure_ffi()
    return string.format('0x%X', tonumber(ffi.cast('uintptr_t', value)))
end

local function dynamic_access_fields(api, game)
    local board = ptr(api, game + patch.board_pointer_rva)
    local campaign = board + patch.campaign_offset
    local record = campaign + patch.planet_dynamic_stride * patch.dynamic_faction_planet
        + patch.planet_dynamic_offset
    assert(api.writable_data(record, patch.planet_dynamic_stride),
        'planet 127 dynamic record is not private writable data')
    local specs = {
        {offset = patch.access_available_offset, before = patch.access_available_before, after = patch.access_available_after},
    }
    local fields = {}
    for _, spec in ipairs(specs) do
        local address = record + spec.offset
        local bytes = assert(api.read(address, 4), 'planet 127 access field unavailable')
        local value = u32(bytes, 0)
        local acceptable = value == spec.before or value == spec.after
        assert(acceptable, 'planet 127 availability field changed')
        fields[#fields + 1] = {address = address, before = bytes, after = pack_u32(spec.after), changed = value ~= spec.after}
    end
    return fields
end

local function apply_dynamic_access(api, game)
    local fields = dynamic_access_fields(api, game)
    local applied = {}
    for _, field in ipairs(fields) do
        if field.changed then
            local ok = api.write(field.address, field.after)
            if not ok or api.read(field.address, 4) ~= field.after then
                for index = #applied, 1, -1 do
                    local prior = applied[index]
                    if api.read(prior.address, 4) == prior.after then
                        pcall(api.write, prior.address, prior.before)
                    end
                end
                error('planet 127 access write readback failed')
            end
            applied[#applied + 1] = field
        end
    end
    return fields, applied
end

local function dynamic_faction_field(api, game)
    local board = ptr(api, game + patch.board_pointer_rva)
    local campaign = board + patch.campaign_offset
    local record = campaign + patch.planet_dynamic_stride * patch.dynamic_faction_planet
        + patch.planet_dynamic_offset
    assert(api.writable_data(record, patch.planet_dynamic_stride),
        'planet 127 dynamic record is not private writable data')
    local address = record + patch.dynamic_faction_offset
    local before = assert(api.read(address, 4), 'planet 127 dynamic faction unavailable')
    local current = u32(before, 0)
    assert(current == patch.dynamic_faction_before or current == patch.dynamic_faction_after,
        'planet 127 dynamic faction is not the expected original or applied value')
    return {address = address, before = before, after = pack_u32(patch.dynamic_faction_after),
        changed = current == patch.dynamic_faction_before, readback = current}
end

local function apply_dynamic_faction(api, game)
    local field = dynamic_faction_field(api, game)
    if not field.changed then return field end
    assert(api.write(field.address, field.after), 'planet 127 dynamic faction write failed')
    assert(api.read(field.address, 4) == field.after,
        'planet 127 dynamic faction write readback failed')
    field.readback = patch.dynamic_faction_after
    return field
end

local function rollback_dynamic_faction(api, field)
    if field and field.changed and api.read(field.address, #field.after) == field.after then
        pcall(api.write, field.address, field.before)
    end
end

local function rollback(api, applied)
    for index = #applied, 1, -1 do
        local field = applied[index]
        if api.read(field.address, #field.after) == field.after then
            pcall(api.write, field.address, field.before)
        end
    end
end

local function current_board(api, game, expected)
    local board = ptr(api, game + patch.board_pointer_rva)
    assert(same_pointer(api, board, expected), 'campaign board owner changed')
    return board
end

local function task_row_planet(row)
    return u32(row, patch.local_row_planet_offset)
end

local function task_row_valid(row)
    return row:byte(patch.local_row_valid_offset + 1) ~= 0
end

local function retarget_task_row(row)
    return row:sub(1, patch.local_row_planet_offset)
        .. pack_u32(patch.task_target_planet)
        .. row:sub(patch.local_row_planet_offset + 5)
end

local function apply_task_fields(api, game, board, fields)
    local applied = {}
    for _, field in ipairs(fields) do
        local ok, reason = pcall(function()
            current_board(api, game, board)
            assert(api.read(field.address, #field.before) == field.before,
                'local task row bytes changed')
            assert(api.write(field.address, field.after), 'local task row write failed')
            applied[#applied + 1] = field
            assert(api.read(field.address, #field.after) == field.after,
                'local task row write readback failed')
        end)
        if not ok then
            rollback(api, applied)
            return nil, tostring(reason):gsub('^.-: ', '')
        end
    end
    return applied
end

local function capture_task_cache(api, game, board, active)
    local base = board + patch.local_rows_offset
    local size = patch.local_rows_capacity * patch.local_row_stride
    if not api.writable_data(base, size) then return end
    local bytes = assert(api.read(base, size), 'local campaign task rows unavailable')

    local excluded = {[patch.task_target_planet] = true}
    local owner = ptr(api, game + patch.globals_pointer_rva)
    local global_bytes = assert(api.read(owner, patch.global_rows * patch.global_row_size),
        'global modifier table unavailable')
    for index = 0, patch.global_rows - 1 do
        local row_base = index * patch.global_row_size
        local total = u32(global_bytes, row_base + patch.global_total_offset)
        local scope = global_bytes:byte(row_base + patch.global_scope_offset + 1)
        local planet = u32(global_bytes, row_base + patch.global_value_offset)
        if total and total > 0 and scope == 0 and planet then excluded[planet] = true end
    end
    -- 268 is intentionally excluded in this variant; only neutral planets
    -- without a planet-level modifier may provide the task template.

    local groups, order = {}, {}
    for index = 0, patch.local_rows_capacity - 1 do
        local row = bytes:sub(index * patch.local_row_stride + 1,
            (index + 1) * patch.local_row_stride)
        if task_row_valid(row) then
            local planet = task_row_planet(row)
            if planet and not excluded[planet] then
                if not groups[planet] then groups[planet], order[#order + 1] = {}, planet end
                groups[planet][#groups[planet] + 1] = row
            end
        end
    end

    local source = groups[patch.task_source_planet] and patch.task_source_planet or nil
    if not source and not task_cache.rows then
        for _, planet in ipairs(order) do
            if planet ~= patch.task_target_planet and not excluded[planet] then
                source = planet
                break
            end
        end
    end
    if source and #groups[source] > 0 then
        task_cache.rows, task_cache.owner, task_cache.source_planet = groups[source], board, source
    end
end

local function ensure_task_rows(api, game)
    local board = ptr(api, game + patch.board_pointer_rva)
    local base = board + patch.local_rows_offset
    local size = patch.local_rows_capacity * patch.local_row_stride
    assert(api.writable_data(base, size), 'local campaign task rows are not private writable data')
    local bytes = assert(api.read(base, size), 'local campaign task rows unavailable')
    local active = u32(assert(api.read(board + patch.active_planet_offset, 4)), 0)
    local hovered = u32(assert(api.read(board + patch.hovered_planet_offset, 4)), 0)
    local valid_268, valid_268_slots, valid_127, valid_other = {}, {}, {}, {}
    for index = 0, patch.local_rows_capacity - 1 do
        local row = bytes:sub(index * patch.local_row_stride + 1,
            (index + 1) * patch.local_row_stride)
        if task_row_valid(row) then
            local planet = task_row_planet(row)
            if planet == patch.task_source_planet then
                valid_268[#valid_268 + 1] = row
                valid_268_slots[#valid_268_slots + 1] = index
            elseif planet == patch.task_target_planet then
                valid_127[#valid_127 + 1] = {index = index, row = row}
            else
                valid_other[#valid_other + 1] = row
            end
        end
    end
    local templates = task_cache.rows
    local source_label = task_cache.source_planet and ('neutral_' .. tostring(task_cache.source_planet)) or 'neutral'
    if not templates or #templates == 0 then
        return {}, 'task_rows=no_neutral_template', false
    end
    if not task_cache.rows then task_cache.rows = templates end
    local active_field
    local fields = {}
    local used = {}
    for _, target in ipairs(valid_127) do used[target.index] = true end
    local function free_slot()
        for index = 0, patch.local_rows_capacity - 1 do
            if not used[index] then
                local row = bytes:sub(index * patch.local_row_stride + 1,
                    (index + 1) * patch.local_row_stride)
                if not task_row_valid(row) then
                    used[index] = true
                    return index
                end
            end
        end
        return nil
    end
    for slot, source_row in ipairs(templates) do
        local index
        local target = valid_127[slot]
        if target then
            index = target.index
        else
            index = free_slot()
        end
        assert(index, 'no free local task row slot for planet 127')
        local before = bytes:sub(index * patch.local_row_stride + 1,
            (index + 1) * patch.local_row_stride)
        local after = retarget_task_row(source_row)
        if before ~= after then
            fields[#fields + 1] = {
                address = base + index * patch.local_row_stride,
                before = before, after = after,
            }
        end
    end
    local applied, reason = apply_task_fields(api, game, board, fields)
    if not applied then
        if active_field and api.read(active_field.address, #active_field.after) == active_field.after then
            pcall(api.write, active_field.address, active_field.before)
        end
        assert(applied, reason)
    end
    if active_field then table.insert(applied, 1, active_field) end
    local suffix = ' :transient' 
    return applied, string.format('task_rows=copy_%s_to_127:%d%s', source_label, #templates, suffix),
        #fields > 0 or active_field ~= nil
end

local function current_owner(api, game, expected)
    local owner = ptr(api, game + patch.globals_pointer_rva)
    assert(same_pointer(api, owner, expected), 'global modifier owner changed')
    return owner
end

local function resolve_tag_id(api, game, definition_id, label)
    local hashes = assert(api.read(game + patch.tag_hashes_rva, patch.tag_count * 4),
        'campaign tag hash table unavailable')
    local defs = ptr(api, game + patch.definition_pointer_rva)
    local count_bytes = assert(api.read(defs + patch.definition_count_offset, 4),
        'campaign modifier definition count unavailable')
    local count = u32(count_bytes, 0)
    assert(count and count <= 1024, 'campaign modifier definition count out of range')
    local rows = assert(api.read(defs, count * patch.definition_stride),
        'campaign modifier definitions unavailable')
    local found
    for i = 0, count - 1 do
        local at = i * patch.definition_stride
        if u32(rows, at) == definition_id then
            assert(not found, 'duplicate ' .. label .. ' modifier definition')
            assert(u32(rows, at + 4) == 40 and u32(rows, at + 24) == 13,
                label .. ' definition shape changed')
            local tag_hash = u32(rows, at + 28)
            for tag = 1, patch.tag_count - 1 do
                if u32(hashes, tag * 4) == tag_hash then found = tag break end
            end
            assert(found, label .. ' tag hash is not in the campaign tag table')
        end
    end
    return assert(found, label .. ' modifier definition ' .. tostring(definition_id) .. ' is unavailable')
end

local function parse_globals(bytes)
    assert(bytes and #bytes == patch.global_rows * patch.global_row_size, 'global modifier table size changed')
    local rows = {}
    for index = 0, patch.global_rows - 1 do
        local base = index * patch.global_row_size
        local total = assert(u32(bytes, base + patch.global_total_offset), 'global entry count unavailable')
        assert(total <= patch.max_entries, 'global modifier entry count out of range')
        local row = {
            index = index,
            base = base,
            total = total,
            scope = bytes:byte(base + patch.global_scope_offset + 1),
            value = u32(bytes, base + patch.global_value_offset),
            filter = u32(bytes, base + patch.global_filter_offset),
            empty = bytes:sub(base + 1, base + patch.global_row_size) == ZERO_ROW,
            tags = {},
        }
        for entry = 0, total - 1 do
            local at = base + entry * patch.global_entry_stride
            local kind = bytes:byte(at + patch.global_entry_type_offset + 1)
            if kind == patch.modifier_entry_type then
                local tag = assert(u32(bytes, at + patch.global_entry_tag_offset),
                    'global modifier tag is truncated')
                assert(tag >= 1 and tag < patch.tag_count, 'global modifier tag is out of range')
                row.tags[#row.tags + 1] = {slot = entry, id = tag}
            end
        end
        rows[#rows + 1] = row
    end
    return rows
end

local function has_tag(row, tag_id)
    for _, entry in ipairs(row.tags) do
        if entry.id == tag_id then return true end
    end
    return false
end

local function apply_fields(api, game, owner, fields)
    local applied = {}
    for _, field in ipairs(fields) do
        local ok, reason = pcall(function()
            current_owner(api, game, owner)
            assert(api.read(field.address, #field.before) == field.before, 'global modifier bytes changed')
            assert(api.write(field.address, field.after), 'global modifier write failed')
            -- The write API promises false means no write. Record the field
            -- only after success so a precondition mismatch cannot overwrite
            -- bytes changed by another owner.
            applied[#applied + 1] = field
            assert(api.read(field.address, #field.after) == field.after, 'global modifier write readback failed')
        end)
        if not ok then
            rollback(api, applied)
            return nil, tostring(reason):gsub('^.-: ', '')
        end
    end
    return true
end

local function plan_planet(rows, bytes, planet, tag_id, used_rows)
    local appendable
    for _, row in ipairs(rows) do
        local is_planet = row.scope == 0 and row.value == planet
        if is_planet and has_tag(row, tag_id)
            and (row.filter == 0 or row.filter == patch.terminid_faction) then
            return {action = 'already_present', row = row.index, count = row.total, fields = {}}
        end
        -- Keep the new tag Terminid-only. Do not append to an unfiltered
        -- planet row because that would enable the tag for another faction.
        if is_planet and row.filter == patch.terminid_faction
            and row.total < patch.max_entries and not used_rows[row.index] then
            appendable = appendable or row
        end
    end

    if appendable then
        local base = appendable.base
        local slot = base + appendable.total * patch.global_entry_stride
        assert(bytes:sub(slot + 1, slot + patch.global_entry_stride) == ZERO_16,
            'planet modifier append slot is occupied')
        used_rows[appendable.index] = true
        return {
            action = 'appended', row = appendable.index, count = appendable.total + 1,
            fields = {
                {offset = slot, before = ZERO_16, after = pack_entry(tag_id)},
                {offset = base + patch.global_total_offset,
                 before = pack_u32(appendable.total), after = pack_u32(appendable.total + 1)},
            },
        }
    end

    local empty_row
    for _, row in ipairs(rows) do
        if row.empty and not used_rows[row.index] then empty_row = row break end
    end
    assert(empty_row, 'no empty global modifier row available')
    used_rows[empty_row.index] = true
    local base = empty_row.base
    return {
        action = 'created', row = empty_row.index, count = 1,
        fields = {
            {offset = base, before = ZERO_16, after = pack_entry(tag_id)},
            {offset = base + patch.global_scope_offset,
             before = pack_u32(0), after = pack_u32(0)},
            {offset = base + patch.global_value_offset,
             before = pack_u32(0), after = pack_u32(planet)},
            {offset = base + patch.global_filter_offset,
             before = pack_u32(0), after = pack_u32(patch.terminid_faction)},
            {offset = base + patch.global_total_offset,
             before = pack_u32(0), after = pack_u32(1)},
        },
    }
end

local function remove_planet_tag(api, game, owner, planet, tag_id)
    local bytes = assert(api.read(owner, patch.global_rows * patch.global_row_size),
        'global modifier table unavailable')
    local rows, fields, removed = parse_globals(bytes), {}, 0
    for _, row in ipairs(rows) do
        if row.scope == 0 and row.value == planet and row.total > 0 then
            local kept = {}
            for slot = 0, row.total - 1 do
                local at = row.base + slot * patch.global_entry_stride
                local entry = bytes:sub(at + 1, at + patch.global_entry_stride)
                local kind = entry:byte(1)
                local entry_tag = u32(entry, patch.global_entry_tag_offset)
                if kind == patch.modifier_entry_type and entry_tag == tag_id then
                    removed = removed + 1
                else
                    kept[#kept + 1] = entry
                end
            end
            if #kept ~= row.total then
                for slot = 0, patch.max_entries - 1 do
                    local at = row.base + slot * patch.global_entry_stride
                    local before = bytes:sub(at + 1, at + patch.global_entry_stride)
                    local after = kept[slot + 1] or ZERO_16
                    if before ~= after then
                        fields[#fields + 1] = {address = owner + at, before = before, after = after}
                    end
                end
                fields[#fields + 1] = {
                    address = owner + row.base + patch.global_total_offset,
                    before = pack_u32(row.total), after = pack_u32(#kept),
                }
            end
        end
    end
    if #fields > 0 then assert(apply_fields(api, game, owner, fields)) end
    return removed, #fields > 0
end

local function ensure_all_planets(api, game, owner, tag_id)
    local bytes = assert(api.read(owner, patch.global_rows * patch.global_row_size),
        'global modifier table unavailable')
    local rows, used_rows, fields, actions = parse_globals(bytes), {}, {}, {}
    for _, planet in ipairs(patch.target_planets) do
        local plan = plan_planet(rows, bytes, planet, tag_id, used_rows)
        actions[#actions + 1] = string.format('%d:%s:r%d:%d', planet, plan.action,
            plan.row, plan.count)
        for _, field in ipairs(plan.fields) do
            fields[#fields + 1] = {
                address = owner + field.offset,
                before = field.before,
                after = field.after,
            }
        end
    end
    if #fields > 0 then assert(apply_fields(api, game, owner, fields)) end
    return #fields > 0, table.concat(actions, ',')
end

function patch.apply(api, game)
    local dynamic_field
    local task_fields, task_detail, task_changed
    local ok, result, mode, row, total = pcall(function()
        local owner = ptr(api, game + patch.globals_pointer_rva)
        assert(api.writable_data(owner, patch.global_rows * patch.global_row_size),
            'global modifier table is not private writable data')
        local tag_id = resolve_tag_id(api, game, patch.modifier_definition_id, 'Spore Burst')
        local fractured_tag_id, remove_detail = nil, 'remove_1241=skipped'
        local remove_ok, remove_result = pcall(resolve_tag_id, api, game, patch.removed_modifier_definition_id, 'Fractured Planet')
        if remove_ok then
            fractured_tag_id = remove_result
            remove_detail = 'remove_1241=ready'
        else
            remove_detail = 'remove_1241=skipped:' .. tostring(remove_result):gsub('^.-: ', '')
        end
        dynamic_field = apply_dynamic_faction(api, game)
        local access_fields, access_applied, access_detail = {}, {}, 'access_fields=skipped'
        local access_ok, access_result, access_written = pcall(apply_dynamic_access, api, game)
        if access_ok then
            access_fields, access_applied = access_result, access_written
            access_detail = (#access_applied > 0) and 'access_fields=applied:127:+0x30' or 'access_fields=already_applied'
        else
            access_detail = 'access_fields=skipped:' .. tostring(access_result):gsub('^.-: ', '')
        end
        local board_now = ptr(api, game + patch.board_pointer_rva)
        local active_now = u32(assert(api.read(board_now + patch.active_planet_offset, 4)), 0)
        local hovered_now = u32(assert(api.read(board_now + patch.hovered_planet_offset, 4)), 0)
        capture_task_cache(api, game, board_now, active_now)
        if patch.task_mutation_enabled and (active_now == patch.task_target_planet or hovered_now == patch.task_target_planet) then
            task_fields, task_detail, task_changed = ensure_task_rows(api, game)
        else
            task_fields, task_detail, task_changed = {}, 'task_rows=idle', false
        end
        local applied, detail = ensure_all_planets(api, game, owner, tag_id)
        local removed_1241, removed_changed = 0, false
        if fractured_tag_id then
            local remove_call_ok, remove_result, remove_writes = pcall(remove_planet_tag, api, game, owner, patch.task_target_planet, fractured_tag_id)
            if remove_call_ok then
                removed_1241, removed_changed = remove_result, remove_writes
                remove_detail = 'remove_1241=removed:' .. tostring(removed_1241)
            else
                remove_detail = 'remove_1241=skipped:' .. tostring(remove_result):gsub('^.-: ', '')
            end
        end
        patch.detail = string.format('modifier=1244 tag=%d owner=%s board=%s planets=%s dynamic_faction=127:before=%d:requested=%d:readback=%d %s %s %s',
            tag_id, hex_address(owner), hex_address(board_now),
            detail .. ',127:removed_1241=' .. tostring(removed_1241), patch.dynamic_faction_before, patch.dynamic_faction_after,
            u32(assert(api.read(dynamic_field.address, 4)), 0), remove_detail, access_detail, task_detail)
        local changed = applied or removed_changed or task_changed or (dynamic_field and dynamic_field.changed) or access_applied and #access_applied > 0
        return true, changed and 'gosporebrust_applied' or 'gosporebrust_ready', true
    end)
    if not ok then
        rollback(api, task_fields or {})
        rollback_dynamic_faction(api, dynamic_field)
        patch.detail = tostring(result):gsub('^.-: ', '')
        return true, 'gosporebrust_waiting', false
    end
    return result, mode, row
end

return patch
