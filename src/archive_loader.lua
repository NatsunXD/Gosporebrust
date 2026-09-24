return function(create_api, patch, build)
    if _G.GoPredator then return end
    local state = {revision = build.revision, active = false, status = '', detail = ''}
    _G.GoPredator = state

    local identity_warning = nil
    local function report(status, active)
        local detail = patch.detail or ''
        if identity_warning then
            detail = (detail ~= '' and (detail .. ' ')) or ''
            detail = detail .. identity_warning
        end
        if state.status == status and state.detail == detail and state.active == active then return end
        state.active, state.status, state.detail = active, status, detail
        print('[GoPredator] ' .. build.revision .. ': ' .. status ..
            (detail ~= '' and (' ' .. detail) or ''))
        pcall(function()
            local loader = rawget(_G, 'CowboyBingusModLoader')
            local file = loader and type(loader.open_log) == 'function'
                and loader.open_log('GoPredator.log') or nil
            if not file then
                local directory = os.getenv('LOCALAPPDATA')
                if directory then file = io.open(directory .. '/GoPredator.log', 'w') end
            end
            if file then
                file:write(build.revision .. '\n' .. status .. '\n' .. detail .. '\n')
                file:close()
            end
        end)
    end

    local ok, api, game = pcall(function()
        local api = create_api()
        local exe, game = api.module(nil), api.module('game.dll')
        assert(exe and game, 'Required game modules unavailable')
        local exe_hash, game_hash = api.module_hash(exe), api.module_hash(game)
        if exe_hash ~= build.exe_sha256 or game_hash ~= build.game_sha256 then
            identity_warning = string.format(
                'identity=warning:exe=%s:expected=%s:game=%s:expected=%s',
                exe_hash, build.exe_sha256, game_hash, build.game_sha256)
            print('[GoPredator] warning: module hash mismatch; continuing with structural checks')
        end
        assert(type(update) == 'function', 'Game update unavailable; no change applied')
        return api, game
    end)
    if not ok then report(tostring(api), false); return end

    local previous = update
    local elapsed = 0.1
    local stopped = false
    local function check(dt)
        if stopped then return end
        elapsed = elapsed + ((type(dt) == 'number' and dt == dt and dt > 0) and dt or 0)
        if elapsed < 0.1 then return end
        elapsed = 0
        local called, accepted, status, active = pcall(patch.apply, api, game)
        if not called then accepted, status, active = true, tostring(accepted), false end
        if not accepted then stopped = true end
        report(tostring(status), active == true)
    end
    local function forward(dt, ...)
        check(dt)
        return ...
    end
    update = function(dt, ...)
        return forward(dt, previous(dt, ...))
    end
end
