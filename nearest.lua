local function safe_env()
    local ok, g = pcall(function()
        return getgenv()
    end)
    if ok and type(g) == 'table' then
        return g
    end
    if type(shared) == 'table' then
        shared.__FINDER_ENV = shared.__FINDER_ENV or {}
        return shared.__FINDER_ENV
    end
    if type(_G) == 'table' then
        _G.__FINDER_ENV = _G.__FINDER_ENV or {}
        return _G.__FINDER_ENV
    end
    return {}
end

local ENV = safe_env()

local INSTANCE_ID = tostring(math.random(1000000, 9999999))
local INSTANCE_DELAY = math.random(0, 200) / 100

if ENV.__FINDER_RUNNING then
    warn('[Finder-' .. INSTANCE_ID .. '] Already running, stopping duplicate...')
    return
end
ENV.__FINDER_RUNNING = true

-- ===================== CONFIG =====================
local PLACE_ID = 109983668079237

-- Webhooks
local webhook_verylow = 'https://discord.com/api/webhooks/1429557869480775782/2OnKxtzO445Qr9aAS_cx-0hicvbEsMrYKjMKm0aBCJj7DCLFw8AOi_EXCpXLkIF04U-n'
local webhook_low = 'https://discord.com/api/webhooks/1429557869480775782/2OnKxtzO445Qr9aAS_cx-0hicvbEsMrYKjMKm0aBCJj7DCLFw8AOi_EXCpXLkIF04U-n'
local webhook_mid = 'https://discord.com/api/webhooks/1429557869480775782/2OnKxtzO445Qr9aAS_cx-0hicvbEsMrYKjMKm0aBCJj7DCLFw8AOi_EXCpXLkIF04U-n'
local webhook_high = 'https://discord.com/api/webhooks/1429557869480775782/2OnKxtzO445Qr9aAS_cx-0hicvbEsMrYKjMKm0aBCJj7DCLFw8AOi_EXCpXLkIF04U-n'
local webhook_highm = 'https://discord.com/api/webhooks/1429557869480775782/2OnKxtzO445Qr9aAS_cx-0hicvbEsMrYKjMKm0aBCJj7DCLFw8AOi_EXCpXLkIF04U-n'
local webhook_clutch = 'https://discord.com/api/webhooks/1429557869480775782/2OnKxtzO445Qr9aAS_cx-0hicvbEsMrYKjMKm0aBCJj7DCLFw8AOi_EXCpXLkIF04U-n'

local EMBED_USERNAME = 'Dark Notifier'
local EMBED_COLOR = 3066993

-- Pool settings
local LIMIT = 100
local SCAN_TIMEOUT = 3
local MAX_SCAN_ITEMS = 150
local MIN_PPS = 1000000

local PRIORITY_NAMES = {
    'Strawberry Elephant',
    'Dragon Cannelloni',
    'Garama and Madundung',
    'La Supreme Combinasion',
    'La Secret Combinasion',
    'Ketchuru and Musturu',
    'Tictac Sahur',
    'Tang Tang Keletang',
    'Tralaledon',
    'Nuclearo Dinossauro',
    'Ketupat Kepat',
    'Spaghetti Tualetti',
}

-- ===================== SERVICES =====================
local Players = game:GetService('Players')
local TeleportService = game:GetService('TeleportService')
local HttpService = game:GetService('HttpService')

local t_wait = task.wait
local t_spawn = task.spawn

math.randomseed(tick() * 1000 + tonumber(INSTANCE_ID))

-- ===================== GLOBAL POOL =====================
if not ENV.__GLOBAL_SERVER_POOL then
    ENV.__GLOBAL_SERVER_POOL = {}
end

if not ENV.__GLOBAL_POOL_LOCK then
    ENV.__GLOBAL_POOL_LOCK = {
        last_refresh = 0,
        refreshing = false
    }
end

-- ===================== HTTP FUNCTIONS =====================
local request_func = (syn and syn.request)
    or (http and http.request)
    or http_request
    or request

local last_request_time = 0

local function throttled_wait()
    local now = tick()
    local elapsed = now - last_request_time
    if elapsed < 0.3 then
        t_wait(0.3 - elapsed)
    end
    last_request_time = tick()
end

local function http_get(url, attempt)
    throttled_wait()
    
    attempt = attempt or 1
    if request_func then
        local success, res = pcall(function()
            return request_func({
                Url = url,
                Method = 'GET',
                Headers = { ['Accept'] = 'application/json' },
            })
        end)
        
        if not success then
            if attempt < 2 then
                t_wait(1)
                return http_get(url, attempt + 1)
            end
            return 0, ''
        end
        
        local code = res.StatusCode or res.Status or 0
        local body = res.Body or res.body or ''
        
        if code == 429 then
            if attempt < 3 then
                local wait_time = 3 * attempt
                warn('[HTTP-' .. INSTANCE_ID .. '] Rate limited! Waiting ' .. wait_time .. 's')
                t_wait(wait_time)
                return http_get(url, attempt + 1)
            end
            return 429, ''
        end
        
        return code, tostring(body)
    else
        local ok, body = pcall(game.HttpGet, game, url)
        return ok and 200 or 0, body or ''
    end
end

local function http_post_json(url, tbl)
    throttled_wait()
    
    if not request_func then
        return nil
    end
    
    local success, res = pcall(function()
        return request_func({
            Url = url,
            Method = 'POST',
            Headers = { ['Content-Type'] = 'application/json' },
            Body = HttpService:JSONEncode(tbl or {}),
        })
    end)
    
    if not success or not res then
        return nil
    end
    
    local code = res.StatusCode or res.Status or 0
    if code >= 200 and code < 300 then
        return true
    end
    
    return nil
end

-- ===================== SERVER POOL =====================
local function buildUrl(placeId, limit, cursor)
    local u = string.format(
        'https://games.roblox.com/v1/games/%d/servers/0?limit=%d&sortOrder=2&excludeFullGames=true',
        placeId,
        limit
    )
    if cursor and cursor ~= '' then
        u = u .. '&cursor=' .. HttpService:UrlEncode(cursor)
    end
    return u
end

local function fetchServersNow()
    print('[FETCH-' .. INSTANCE_ID .. '] Fetching servers...')
    
    local code, body = http_get(buildUrl(PLACE_ID, LIMIT, nil))
    
    if code == 429 then
        warn('[FETCH-' .. INSTANCE_ID .. '] Rate limited')
        return {}
    end
    
    if code ~= 200 then
        return {}
    end
    
    local ok, obj = pcall(function()
        return HttpService:JSONDecode(body)
    end)
    
    if not ok or not obj or not obj.data then
        return {}
    end
    
    local ids = {}
    for _, server in ipairs(obj.data) do
        local id = server.id
        local playing = tonumber(server.playing) or 0
        local maxPlayers = tonumber(server.maxPlayers) or 8
        
        -- FILTRO: Apenas servidores com 1-7 players (evita cheios e vazios)
        if id and playing >= 1 and playing <= 7 and id ~= game.JobId then
            table.insert(ids, id)
        end
    end
    
    print('[FETCH-' .. INSTANCE_ID .. '] Found ' .. #ids .. ' servers (1-7 players)')
    return ids
end

local function tryLockRefresh()
    local lock = ENV.__GLOBAL_POOL_LOCK
    local now = tick()
    
    if lock.refreshing then
        return false
    end
    
    if now - lock.last_refresh < 5 then
        return false
    end
    
    lock.refreshing = true
    lock.last_refresh = now
    return true
end

local function unlockRefresh()
    ENV.__GLOBAL_POOL_LOCK.refreshing = false
end

local function refreshServerPool()
    if not tryLockRefresh() then
        return false
    end
    
    local ids = fetchServersNow()
    
    for i = #ids, 2, -1 do
        local j = math.random(i)
        ids[i], ids[j] = ids[j], ids[i]
    end
    
    local pool = ENV.__GLOBAL_SERVER_POOL
    local existing = {}
    for _, id in ipairs(pool) do
        existing[id] = true
    end
    
    for _, id in ipairs(ids) do
        if not existing[id] then
            table.insert(pool, id)
        end
    end
    
    unlockRefresh()
    
    print('[POOL-' .. INSTANCE_ID .. '] Pool now has ' .. #pool .. ' servers')
    return #ids > 0
end

local function getRandomServerId()
    local pool = ENV.__GLOBAL_SERVER_POOL
    
    if #pool == 0 then
        return nil
    end
    
    local idx = math.random(#pool)
    local id = table.remove(pool, idx)
    
    return id
end

-- ===================== PARSING UTILITIES =====================
local suffixMul = {
    K = 1000,
    M = 1000000,
    B = 1000000000,
    T = 1000000000000,
}

local function parsePps(txt)
    if type(txt) ~= 'string' then
        return nil
    end
    
    local s = txt:gsub('%$', ''):gsub('/s', ''):gsub('%s+', '')
    local num, suf = s:match('^([%d%.]+)([KkMmBbTt]?)$')
    local n = tonumber(num)
    
    if not n then
        return nil
    end
    
    if suf ~= '' then
        n = n * (suffixMul[suf:upper()] or 1)
    end
    
    return n
end

local function human(n)
    if n >= 1000000000000 then
        return string.format('%.2f', n / 1000000000000):gsub('%.?0+$', '') .. 'T'
    elseif n >= 1000000000 then
        return string.format('%.2f', n / 1000000000):gsub('%.?0+$', '') .. 'B'
    elseif n >= 1000000 then
        return string.format('%.2f', n / 1000000):gsub('%.?0+$', '') .. 'M'
    elseif n >= 1000 then
        return string.format('%.2f', n / 1000):gsub('%.?0+$', '') .. 'K'
    end
    return tostring(math.floor(n))
end

local function slugifyTitleCase(name)
    local parts = {}
    for token in tostring(name):gsub('[^%w%s]', ' '):gsub('%s+', ' '):gmatch('%S+') do
        table.insert(parts, token:sub(1, 1):upper() .. token:sub(2):lower())
    end
    return table.concat(parts, '-')
end

local function wikiThumb(name)
    return 'https://steal-a-brainrot.wiki/wp-content/uploads/2025/07/' .. slugifyTitleCase(name) .. '.png'
end

-- ===================== SCANNING =====================
local ROOT_PLOTS = workspace:WaitForChild('Plots', 5) or workspace

local function safeFind(parent, name, recursive)
    if not parent then return nil end
    local ok, result = pcall(function()
        return parent:FindFirstChild(name, recursive)
    end)
    return ok and result or nil
end

local function safeGetText(obj)
    if not obj then return nil end
    
    local ok, text = pcall(function()
        if obj:IsA('TextLabel') or obj:IsA('TextButton') then
            return obj.Text
        elseif obj:IsA('StringValue') then
            return obj.Value
        end
    end)
    
    if ok and type(text) == 'string' and text ~= '' then
        return text
    end
    
    return nil
end

local function findPerSecondText(overhead)
    local gen = safeFind(overhead, 'Generation', true)
    local txt = safeGetText(gen)
    
    if txt and txt:find('/s', 1, true) then
        return txt
    end
    
    return nil
end

local function resolveMutation(overhead)
    local mNode = safeFind(overhead, 'Mutation', true)
    if not mNode then
        return 'Normal'
    end
    
    local txt = safeGetText(mNode)
    if not txt or txt == '' then
        return 'Normal'
    end
    
    return txt:gsub('<.->', '')
end

local function getDisplayName(overhead)
    return safeGetText(safeFind(overhead, 'DisplayName', true))
end

local function getBaseOwner(plotRoot)
    if not plotRoot then
        return 'Unknown'
    end
    
    local sign = safeFind(plotRoot, 'PlotSign', true)
    if not sign then
        return 'Unknown'
    end
    
    local sg = safeFind(sign, 'SurfaceGui', true)
    if sg then
        local frame = safeFind(sg, 'Frame', true)
        if frame then
            local label = frame:FindFirstChildWhichIsA('TextLabel', true)
            if label then
                local text = safeGetText(label)
                if text then
                    local owner = text:match("^(.-)%s*'s")
                    if owner and owner ~= '' then
                        return owner:match('^%s*(.-)%s*$')
                    end
                end
            end
        end
    end
    
    return 'Unknown'
end

local function getPlotRoot(overhead)
    local p = overhead
    while p and p ~= ROOT_PLOTS and p.Parent do
        if p.Parent == ROOT_PLOTS then
            return p
        end
        p = p.Parent
    end
    return nil
end

local PRIORITY_MAP = {}
for i, name in ipairs(PRIORITY_NAMES) do
    PRIORITY_MAP[name:lower()] = i
end

local function collectAllRows()
    local rows = {}
    local startTime = tick()
    local count = 0
    
    local descendants = ROOT_PLOTS:GetDescendants()
    
    for _, d in ipairs(descendants) do
        if tick() - startTime > SCAN_TIMEOUT then
            break
        end
        
        if count >= MAX_SCAN_ITEMS then
            break
        end
        
        if d.Name == 'AnimalOverhead' and d:IsDescendantOf(workspace) then
            count = count + 1
            
            local plotRoot = getPlotRoot(d)
            local base = getBaseOwner(plotRoot)
            local display = getDisplayName(d) or ''
            local mutation = resolveMutation(d)
            local ppsText = findPerSecondText(d)
            local ppsNum = parsePps(ppsText) or 0
            
            if ppsNum >= MIN_PPS then
                local priRank = PRIORITY_MAP[display:lower()] or math.huge
                
                table.insert(rows, {
                    base = base,
                    display = display,
                    mutation = mutation,
                    perSecond = ppsNum,
                    priRank = priRank,
                    isPriority = (priRank ~= math.huge),
                })
            end
        end
    end
    
    return rows
end

local function pickBest(rows)
    local best = nil
    local bestRank = math.huge
    
    for _, r in ipairs(rows) do
        if r.isPriority then
            if r.priRank < bestRank or (r.priRank == bestRank and r.perSecond > (best and best.perSecond or 0)) then
                best = r
                bestRank = r.priRank
            end
        end
    end
    
    if not best then
        for _, r in ipairs(rows) do
            if not best or r.perSecond > best.perSecond then
                best = r
            end
        end
    end
    
    return best
end

local function groupByBase(rows)
    local groups = {}
    local order = {}
    
    for _, r in ipairs(rows) do
        local g = groups[r.base]
        if not g then
            g = { items = {}, bestPps = r.perSecond, base = r.base }
            groups[r.base] = g
            table.insert(order, r.base)
        else
            if r.perSecond > g.bestPps then
                g.bestPps = r.perSecond
            end
        end
        
        table.insert(g.items, {
            mutation = r.mutation,
            display = r.display,
            perSecond = r.perSecond
        })
    end
    
    for _, base in ipairs(order) do
        table.sort(groups[base].items, function(a, b)
            return a.perSecond > b.perSecond
        end)
    end
    
    table.sort(order, function(a, b)
        return groups[a].bestPps > groups[b].bestPps
    end)
    
    local arr = {}
    for _, base in ipairs(order) do
        table.insert(arr, { base = base, items = groups[base].items })
    end
    
    return arr
end

-- ===================== WEBHOOKS =====================
ENV.__posted_keys = ENV.__posted_keys or {}

local function alreadyPosted(jobId, hook)
    local key = tostring(jobId) .. '|' .. tostring(hook)
    return ENV.__posted_keys[key] ~= nil
end

local function markPosted(jobId, hook)
    local key = tostring(jobId) .. '|' .. tostring(hook)
    ENV.__posted_keys[key] = true
end

local ONE_M = 1000000
local TEN_M = 10000000
local FIFTY_M = 50000000
local HUND_M = 100000000
local FIVEH_M = 500000000

local function chooseTierHook(bestNum)
    if bestNum >= FIVEH_M then
        return webhook_highm, FIVEH_M
    elseif bestNum >= HUND_M then
        return webhook_high, HUND_M
    elseif bestNum >= FIFTY_M then
        return webhook_mid, FIFTY_M
    elseif bestNum >= TEN_M then
        return webhook_low, TEN_M
    elseif bestNum >= ONE_M then
        return webhook_verylow, ONE_M
    end
    return nil, 0
end

local MAX_FIELD = 1024

local function humanGroups(groups, lowerBound)
    local blocks = {}
    
    for _, g in ipairs(groups) do
        local lines = {}
        for _, it in ipairs(g.items) do
            if it.perSecond >= lowerBound then
                table.insert(lines, string.format('• %s - %s - ($%s/s)',
                    it.mutation,
                    it.display,
                    human(it.perSecond)
                ))
            end
        end
        
        if #lines > 0 then
            table.insert(blocks, 'Base: ' .. g.base)
            table.insert(blocks, table.concat(lines, '\n'))
        end
    end
    
    local txt = table.concat(blocks, '\n\n')
    if #txt > MAX_FIELD then
        txt = txt:sub(1, MAX_FIELD - 3) .. '...'
    end
    
    return txt
end

local PRIORITY_SET = {}
for _, n in ipairs(PRIORITY_NAMES) do
    PRIORITY_SET[n:lower()] = true
end

local function humanClutch(groups)
    local blocks = {}
    
    for _, g in ipairs(groups) do
        local lines = {}
        for _, it in ipairs(g.items) do
            if it.perSecond >= FIFTY_M or PRIORITY_SET[it.display:lower()] then
                table.insert(lines, string.format('• %s - %s - ($%s/s)',
                    it.mutation,
                    it.display,
                    human(it.perSecond)
                ))
            end
        end
        
        if #lines > 0 then
            table.insert(blocks, 'Base: ' .. g.base)
            table.insert(blocks, table.concat(lines, '\n'))
        end
    end
    
    local txt = table.concat(blocks, '\n\n')
    if #txt > MAX_FIELD then
        txt = txt:sub(1, MAX_FIELD - 3) .. '...'
    end
    
    return txt
end

local function postWebhooks(bestRow, grouped)
    if not bestRow then return end
    
    local bestNum = bestRow.perSecond
    local tierHook, lowerBound = chooseTierHook(bestNum)
    local jobId = tostring(game.JobId)
    
    if tierHook and not alreadyPosted(jobId, tierHook) then
        t_spawn(function()
            local playersNow = #Players:GetPlayers()
            local maxPlayers = 8
            local playersShown = math.min(playersNow, maxPlayers - 1)
            
            local payload = {
                username = EMBED_USERNAME,
                embeds = {{
                    title = 'Finder',
                    description = string.format('**Best:** %s - %s - ($%s/s)\n**Players:** %d/%d',
                        bestRow.mutation,
                        bestRow.display,
                        human(bestNum),
                        playersShown,
                        maxPlayers
                    ),
                    color = EMBED_COLOR,
                    thumbnail = { url = wikiThumb(bestRow.display) },
                    fields = {
                        { name = 'Job ID', value = '```' .. jobId .. '```', inline = false },
                        { name = 'Brainrots', value = humanGroups(grouped, lowerBound), inline = false },
                    },
                }},
            }
            
            if http_post_json(tierHook, payload) then
                markPosted(jobId, tierHook)
            end
        end)
    end
    
    local clutchText = humanClutch(grouped)
    if clutchText ~= '' and not alreadyPosted(jobId, webhook_clutch) then
        t_spawn(function()
            local payload = {
                username = EMBED_USERNAME,
                embeds = {{
                    title = 'Finder — Highlight',
                    description = string.format('**Best:** %s - %s - ($%s/s)',
                        bestRow.mutation,
                        bestRow.display,
                        human(bestNum)
                    ),
                    color = EMBED_COLOR,
                    thumbnail = { url = wikiThumb(bestRow.display) },
                    fields = {
                        { name = 'Highlights', value = clutchText, inline = false },
                    },
                }},
            }
            
            if http_post_json(webhook_clutch, payload) then
                markPosted(jobId, webhook_clutch)
            end
        end)
    end
end

-- ===================== HOP SYSTEM (ULTRA RÁPIDO) =====================
local hopInProgress = false

-- Detecta falha de teleport INSTANTANEAMENTE
local function setupTeleportFailDetection()
    local conn
    conn = TeleportService.TeleportInitFailed:Connect(function(player, result, errorMsg)
        if player == Players.LocalPlayer then
            warn('[HOP-' .. INSTANCE_ID .. '] Teleport FAILED: ' .. tostring(result) .. ' - ' .. tostring(errorMsg))
            hopInProgress = false
            
            -- Se falhou porque está cheio, tenta IMEDIATAMENTE outro
            if tostring(result):find('Full') or tostring(errorMsg):find('full') then
                print('[HOP-' .. INSTANCE_ID .. '] Server FULL detected! Trying next immediately...')
                t_spawn(function()
                    t_wait(0.1)  -- Delay mínimo
                    attemptHop()
                end)
            end
        end
    end)
end

-- Fallback sem ID específico
local function hopWithoutId()
    print('[HOP-' .. INSTANCE_ID .. '] Using fallback teleport...')
    
    local ok = pcall(function()
        TeleportService:Teleport(PLACE_ID, Players.LocalPlayer)
    end)
    
    return ok
end

function attemptHop()
    if hopInProgress then
        return false
    end
    
    hopInProgress = true
    
    -- Tenta pegar ID do pool
    local id = getRandomServerId()
    
    if id then
        print('[HOP-' .. INSTANCE_ID .. '] Hopping to: ' .. id)
        
        local ok, err = pcall(function()
            TeleportService:TeleportToPlaceInstance(PLACE_ID, id, Players.LocalPlayer)
        end)
        
        if ok then
            -- Teleport iniciado com sucesso
            print('[HOP-' .. INSTANCE_ID .. '] Teleport initiated!')
            return true
        else
            warn('[HOP-' .. INSTANCE_ID .. '] TeleportToPlaceInstance error: ' .. tostring(err))
            hopInProgress = false
        end
    end
    
    -- Fallback
    local ok = hopWithoutId()
    if not ok then
        hopInProgress = false
    end
    
    return ok
end

-- ===================== MAIN =====================
t_spawn(function()
    print('[Finder-' .. INSTANCE_ID .. '] Starting with ' .. string.format('%.2f', INSTANCE_DELAY) .. 's delay...')
    t_wait(INSTANCE_DELAY)
    
    if not game:IsLoaded() then
        game.Loaded:Wait()
    end
    
    -- Setup detecção de falha de teleport
    setupTeleportFailDetection()
    
    -- Carrega pool em background
    t_spawn(function()
        t_wait(math.random(1, 4))
        refreshServerPool()
    end)
    
    t_wait(2.5)
    
    -- Scan
    print('[Finder-' .. INSTANCE_ID .. '] Scanning server...')
    local rows = collectAllRows()
    
    print('[Finder-' .. INSTANCE_ID .. '] Found ' .. #rows .. ' items')
    
    if #rows > 0 then
        local best = pickBest(rows)
        local grouped = groupByBase(rows)
        
        if best then
            print('[Finder-' .. INSTANCE_ID .. '] Best: ' .. best.display .. ' - $' .. human(best.perSecond) .. '/s')
            postWebhooks(best, grouped)
        end
    end
    
    t_wait(2)
    
    -- Hop loop AGRESSIVO
    print('[Finder-' .. INSTANCE_ID .. '] Starting FAST hop loop...')
    local attempts = 0
    
    while true do
        attempts = attempts + 1
        
        -- Refresh pool a cada 5 tentativas
        if attempts % 5 == 0 then
            t_spawn(function()
                t_wait(1)
                refreshServerPool()
            end)
        end
        
        if not hopInProgress then
            print('[HOP-' .. INSTANCE_ID .. '] Attempt ' .. attempts)
            
            if attemptHop() then
                -- Espera curta para ver se teleport vai acontecer
                t_wait(3)
                
                -- Se ainda em progresso, espera mais um pouco
                if hopInProgress then
                    t_wait(5)
                end
            else
                -- Falhou imediatamente, tenta de novo rápido
                t_wait(0.5)
            end
        else
            -- Já tem um hop em progresso, espera
            t_wait(2)
        end
    end
end)

print('[Finder-' .. INSTANCE_ID .. '] Loaded!')
