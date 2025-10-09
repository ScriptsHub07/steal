local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local module = {}
local cache = {}
local usedServers = {} -- Rastreia servidores já utilizados
local lastFetch = 0
local CACHE_TIMEOUT = 60
local PLACE_ID = game.PlaceId
local MAX_SERVERS = 100
local REQUEST_DELAY = 1

-- Cache de fallback para quando a API falhar
local fallbackCache = {}
local lastFallbackUpdate = 0
local FALLBACK_TIMEOUT = 300 -- 5 minutos

-- ID único para cada instância do script (para identificar contas diferentes)
local SESSION_ID = HttpService:GenerateGUID(false)

-- Coordenação entre múltiplas instâncias (usando DataStore ou arquivo compartilhado)
local coordinationEnabled = false
local sharedUsedServers = {}

local function handleApiError(errorMsg)
    warn("[hop] Erro na API: " .. tostring(errorMsg))
    
    -- Se o cache de fallback estiver atualizado, usar ele
    if #fallbackCache > 0 and (tick() - lastFallbackUpdate < FALLBACK_TIMEOUT) then
        print("[hop] Usando cache de fallback")
        return fallbackCache
    end
    
    return {}
end

local function fetchServers()
    local servers = {}
    local cursor = ""
    local serversFetched = 0
    local attempts = 0
    local maxAttempts = 3
    
    while serversFetched < MAX_SERVERS and attempts < maxAttempts do
        local url = "https://games.roblox.com/v1/games/"..PLACE_ID.."/servers/Public?sortOrder=Asc&limit=100"
        
        if cursor ~= "" then
            url = url .. "&cursor=" .. cursor
        end
        
        local success, result = pcall(function()
            local response = game:HttpGet(url, true)
            return HttpService:JSONDecode(response)
        end)
        
        if not success then
            attempts += 1
            warn("[hop] Tentativa " .. attempts .. " falhou, aguardando...")
            task.wait(REQUEST_DELAY * 2)
            continue
        end
        
        if result and result.data then
            for _, server in pairs(result.data) do
                if serversFetched >= MAX_SERVERS then
                    break
                end
                
                local maxPlayers = tonumber(server.maxPlayers)
                local playing = tonumber(server.playing)
                local serverId = server.id
                
                if maxPlayers and playing and serverId and maxPlayers > playing then
                    -- Verificar se o servidor já foi usado recentemente
                    if not usedServers[serverId] then
                        table.insert(servers, {
                            id = serverId,
                            playing = playing,
                            maxPlayers = maxPlayers
                        })
                        serversFetched = serversFetched + 1
                    end
                end
            end
            
            -- Atualizar cache de fallback
            if #servers > 0 then
                fallbackCache = table.clone(servers)
                lastFallbackUpdate = tick()
            end
            
            -- Verificar paginação
            if result.nextPageCursor and serversFetched < MAX_SERVERS then
                cursor = result.nextPageCursor
            else
                break
            end
        else
            attempts += 1
            warn("[hop] Resposta inválida da API, tentativa " .. attempts)
        end
        
        task.wait(REQUEST_DELAY)
    end
    
    if #servers == 0 and #fallbackCache > 0 then
        print("[hop] Usando cache de fallback como backup")
        return fallbackCache
    end
    
    -- Ordenar servidores por ocupação (menos jogadores primeiro)
    table.sort(servers, function(a, b)
        return a.playing < b.playing
    end)
    
    return servers
end

-- Marcar servidor como usado
local function markServerUsed(serverId)
    usedServers[serverId] = tick()
    
    -- Limpar servidores antigos da lista de usados (após 5 minutos)
    for id, timestamp in pairs(usedServers) do
        if tick() - timestamp > 300 then
            usedServers[id] = nil
        end
    end
end

-- Estratégia de seleção de servidor
local function selectBestServer(servers)
    if #servers == 0 then
        return nil
    end
    
    -- Filtrar servidores não utilizados
    local availableServers = {}
    for _, server in ipairs(servers) do
        if not usedServers[server.id] then
            table.insert(availableServers, server)
        end
    end
    
    if #availableServers == 0 then
        -- Se todos os servidores foram usados, escolher um aleatório
        print("[hop] Todos os servidores foram utilizados, escolhendo aleatoriamente")
        return servers[math.random(1, #servers)]
    end
    
    -- Estratégia: escolher servidor com menos jogadores
    table.sort(availableServers, function(a, b)
        local occupancyA = a.playing / a.maxPlayers
        local occupancyB = b.playing / b.maxPlayers
        return occupancyA < occupancyB
    end)
    
    -- Escolher entre os 3 melhores servidores para distribuir melhor
    local topCount = math.min(3, #availableServers)
    return availableServers[math.random(1, topCount)]
end

function module:Teleport(placeId)
    local targetPlaceId = placeId or PLACE_ID
    local teleportAttempts = 0
    local maxTeleportAttempts = 50
    
    -- Delay aleatório inicial para evitar sincronização
    local initialDelay = math.random(1, 5)
    print("[hop] Aguardando " .. initialDelay .. " segundos antes de iniciar...")
    task.wait(initialDelay)
    
    while teleportAttempts < maxTeleportAttempts do
        -- Limpar cache se expirado
        if #cache == 0 or (tick() - lastFetch > CACHE_TIMEOUT) then
            print("[hop] [" .. SESSION_ID .. "] Buscando servidores...")
            cache = fetchServers()
            lastFetch = tick()
            
            if #cache == 0 then
                warn("[hop] Nenhum servidor encontrado, tentando novamente em 15 segundos.")
                task.wait(15)
                continue
            else
                print("[hop] Encontrados " .. #cache .. " servidores disponíveis")
            end
        end

        local selectedServer = selectBestServer(cache)
        
        if selectedServer then
            -- Remover servidor selecionado do cache
            for i, server in ipairs(cache) do
                if server.id == selectedServer.id then
                    table.remove(cache, i)
                    break
                end
            end
            
            teleportAttempts += 1
            print("[hop] Tentativa " .. teleportAttempts .. ": Teleportando para servidor " .. selectedServer.id .. " (" .. selectedServer.playing .. "/" .. selectedServer.maxPlayers .. " jogadores)")
            
            -- Marcar como usado antes do teleporte
            markServerUsed(selectedServer.id)
            
            local success, errorMsg = pcall(function()
                TeleportService:TeleportToPlaceInstance(targetPlaceId, selectedServer.id, Players.LocalPlayer)
            end)
            
            if not success then
                warn("[hop] Erro no teleporte: " .. tostring(errorMsg))
                -- Se falhou, remover da lista de usados para tentar novamente depois
                usedServers[selectedServer.id] = nil
            end
            
            -- Aguardar antes da próxima tentativa (com jitter)
            local baseWaitTime = math.min(3 + (teleportAttempts * 0.5), 10)
            local jitter = math.random(1, 3) -- Adicionar variação
            local waitTime = baseWaitTime + jitter
            print("[hop] Aguardando " .. waitTime .. " segundos antes da próxima tentativa")
            task.wait(waitTime)
        else
            -- Nenhum servidor adequado encontrado
            cache = {}
            task.wait(6)
        end
    end
    
    warn("[hop] Máximo de tentativas de teleporte atingido")
end

-- Função para forçar atualização do cache
function module:RefreshCache()
    cache = {}
    lastFetch = 0
    print("[hop] Cache forçado a atualizar")
end

-- Função para limpar servidores usados
function module:ClearUsedServers()
    usedServers = {}
    print("[hop] Lista de servidores usados limpa")
end

-- Função para obter estatísticas
function module:GetStats()
    local usedCount = 0
    for _ in pairs(usedServers) do
        usedCount += 1
    end
    
    return {
        cachedServers = #cache,
        lastFetch = lastFetch,
        fallbackServers = #fallbackCache,
        usedServersCount = usedCount,
        sessionId = SESSION_ID
    }
end

return module
