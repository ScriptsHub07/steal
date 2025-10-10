local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local module = {}
local cache = {}
local usedServers = {}
local lastFetch = 0
local CACHE_TIMEOUT = 30 -- Cache mais curto para dados mais frescos
local PLACE_ID = game.PlaceId
local MAX_SERVERS = 50 -- Focado em servidores com boa capacidade
local REQUEST_DELAY = 0.5 -- Delay reduzido

-- Cache local para evitar chamadas desnecessárias à API
local apiCache = {
    data = {},
    lastUpdate = 0,
    cacheTime = 10 -- 10 segundos de cache da API
}

-- Otimização: pré-filtrar servidores por ocupação
local MIN_PLAYERS = 5  -- Mínimo de jogadores para evitar servidores vazios
local MAX_OCCUPANCY = 0.8 -- Máximo 80% de ocupação

local function fetchServersFast()
    -- Usar cache local se ainda estiver válido
    if tick() - apiCache.lastUpdate < apiCache.cacheTime and #apiCache.data > 0 then
        return table.clone(apiCache.data)
    end

    local servers = {}
    local cursor = ""
    local serversFetched = 0
    local attempts = 0
    local maxAttempts = 2
    
    while serversFetched < MAX_SERVERS and attempts < maxAttempts do
        local url = "https://games.roblox.com/v1/games/"..PLACE_ID.."/servers/Public?sortOrder=Asc&limit=100"
        
        if cursor ~= "" then
            url = url .. "&cursor=" .. cursor
        end
        
        local success, result = pcall(function()
            -- Headers para evitar rate limiting
            local success, response = pcall(function()
                return game:HttpGet(url, false) -- false para não usar enableHttpExceptions
            end)
            
            if not success then
                return nil
            end
            
            return HttpService:JSONDecode(response)
        end)
        
        if not success or not result then
            attempts += 1
            if attempts < maxAttempts then
                task.wait(REQUEST_DELAY * 3) -- Wait longer on failure
            end
            continue
        end
        
        if result and result.data then
            for _, server in pairs(result.data) do
                if serversFetched >= MAX_SERVERS then
                    break
                end
                
                local maxPlayers = tonumber(server.maxPlayers) or 0
                local playing = tonumber(server.playing) or 0
                local serverId = server.id
                
                -- Filtro mais eficiente: servidores com jogadores mas não lotados
                if serverId and playing >= MIN_PLAYERS and maxPlayers > playing then
                    local occupancy = playing / maxPlayers
                    if occupancy <= MAX_OCCUPANCY then
                        table.insert(servers, {
                            id = serverId,
                            playing = playing,
                            maxPlayers = maxPlayers,
                            occupancy = occupancy
                        })
                        serversFetched = serversFetched + 1
                    end
                end
            end
            
            -- Atualizar cache da API
            if #servers > 0 then
                apiCache.data = table.clone(servers)
                apiCache.lastUpdate = tick()
            end
            
            -- Paginação
            if result.nextPageCursor and serversFetched < MAX_SERVERS then
                cursor = result.nextPageCursor
                task.wait(REQUEST_DELAY)
            else
                break
            end
        else
            attempts += 1
        end
    end
    
    -- Ordenar por ocupação (menos ocupados primeiro)
    table.sort(servers, function(a, b)
        return a.occupancy < b.occupancy
    end)
    
    return servers
end

function module:Teleport(placeId)
    local targetPlaceId = placeId or PLACE_ID
    local teleportAttempts = 0
    local maxTeleportAttempts = 20 -- Menos tentativas, mais rápidas
    
    -- Delay inicial muito curto
    local initialDelay = math.random(0.5, 2)
    task.wait(initialDelay)
    
    while teleportAttempts < maxTeleportAttempts do
        -- Buscar servidores se cache estiver vazio ou expirado
        if #cache == 0 or (tick() - lastFetch > CACHE_TIMEOUT) then
            cache = fetchServersFast()
            lastFetch = tick()
            
            if #cache == 0 then
                warn("[hop] Nenhum servidor adequado encontrado, tentando novamente em 5 segundos.")
                task.wait(5)
                continue
            end
        end

        -- Selecionar o melhor servidor disponível
        local bestServer = nil
        local bestIndex = 0
        
        for i, server in ipairs(cache) do
            if not usedServers[server.id] then
                bestServer = server
                bestIndex = i
                break
            end
        end
        
        -- Se todos foram usados, escolher um aleatório
        if not bestServer and #cache > 0 then
            bestIndex = math.random(1, #cache)
            bestServer = cache[bestIndex]
            print("[hop] Reutilizando servidor (todos foram usados)")
        end
        
        if bestServer then
            -- Remover do cache
            table.remove(cache, bestIndex)
            
            teleportAttempts += 1
            
            -- Marcar como usado (com timeout curto)
            usedServers[bestServer.id] = tick()
            
            -- Limpar servidores antigos
            for id, timestamp in pairs(usedServers) do
                if tick() - timestamp > 180 then -- 3 minutos
                    usedServers[id] = nil
                end
            end
            
            -- Tentativa de teleporte rápida
            local success, errorMsg = pcall(function()
                TeleportService:TeleportToPlaceInstance(targetPlaceId, bestServer.id, Players.LocalPlayer)
            end)
            
            if success then
                print("[hop] ✅ Teleporte iniciado para servidor com " .. bestServer.playing .. "/" .. bestServer.maxPlayers .. " jogadores")
                return true
            else
                warn("[hop] ❌ Erro no teleporte: " .. tostring(errorMsg))
                -- Não remover da lista de usados se falhou - pode ser um servidor problemático
            end
            
            -- Wait muito curto entre tentativas
            local waitTime = math.random(1, 3) -- 1-3 segundos
            task.wait(waitTime)
            
        else
            -- Cache vazio
            cache = {}
            task.wait(2)
        end
    end
    
    warn("[hop] ❌ Máximo de tentativas de teleporte atingido")
    return false
end

-- Versão ULTRA RÁPIDA - para quando velocidade é crítica
function module:TeleportFast(placeId)
    local targetPlaceId = placeId or PLACE_ID
    
    -- Buscar servidores uma vez
    local servers = fetchServersFast()
    if #servers == 0 then
        warn("[hop] ❌ Nenhum servidor encontrado para teleporte rápido")
        return false
    end
    
    -- Tentar os 3 melhores servidores rapidamente
    for i = 1, math.min(3, #servers) do
        local server = servers[i]
        
        local success, errorMsg = pcall(function()
            TeleportService:TeleportToPlaceInstance(targetPlaceId, server.id, Players.LocalPlayer)
        end)
        
        if success then
            print("[hop] ✅ Teleporte rápido realizado para servidor " .. server.id)
            return true
        else
            warn("[hop] ❌ Falha rápida " .. i .. ": " .. tostring(errorMsg))
            task.wait(0.5) -- Wait muito curto
        end
    end
    
    return false
end

-- Função para múltiplas contas com coordenação
function module:TeleportWithCoordination(placeId, accountId)
    local targetPlaceId = placeId or PLACE_ID
    
    -- Usar accountId para criar delays diferentes
    local accountDelay = ((accountId or 1) - 1) * 2 -- 2 segundos entre cada conta
    task.wait(accountDelay)
    
    return self:Teleport(targetPlaceId)
end

-- Funções utilitárias
function module:RefreshCache()
    cache = {}
    lastFetch = 0
    apiCache.lastUpdate = 0
    print("[hop] ♻️ Cache limpo")
end

function module:ClearUsedServers()
    usedServers = {}
    print("[hop] 🗑️ Lista de servidores usados limpa")
end

function module:GetStats()
    local usedCount = 0
    for _ in pairs(usedServers) do
        usedCount += 1
    end
    
    return {
        cachedServers = #cache,
        usedServers = usedCount,
        apiCacheAge = tick() - apiCache.lastUpdate
    }
end

return module
