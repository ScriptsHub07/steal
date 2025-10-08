local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local module = {}
local cache = {}
local lastFetch = 0
local CACHE_TIMEOUT = 60
local PLACE_ID = game.PlaceId
local MAX_SERVERS = 100 -- Reduzido para evitar rate limiting
local REQUEST_DELAY = 1 -- Aumentado para evitar rate limiting

-- Cache de fallback para quando a API falhar
local fallbackCache = {}
local lastFallbackUpdate = 0
local FALLBACK_TIMEOUT = 300 -- 5 minutos

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
            local response = game:HttpGet(url, true) -- true para enableHttpExceptions
            return HttpService:JSONDecode(response)
        end)
        
        if not success then
            attempts += 1
            warn("[hop] Tentativa " .. attempts .. " falhou, aguardando...")
            task.wait(REQUEST_DELAY * 2) -- Dobra o delay em caso de erro
            continue
        end
        
        if result and result.data then
            for _, server in pairs(result.data) do
                if serversFetched >= MAX_SERVERS then
                    break
                end
                
                -- Verificação mais robusta dos dados do servidor
                local maxPlayers = tonumber(server.maxPlayers)
                local playing = tonumber(server.playing)
                local serverId = server.id
                
                if maxPlayers and playing and serverId and maxPlayers > playing then
                    table.insert(servers, serverId)
                    serversFetched = serversFetched + 1
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
    
    return servers
end

function module:Teleport(placeId)
    local targetPlaceId = placeId or PLACE_ID
    local teleportAttempts = 0
    local maxTeleportAttempts = 50
    
    while teleportAttempts < maxTeleportAttempts do
        -- Limpar cache se expirado
        if #cache == 0 or (tick() - lastFetch > CACHE_TIMEOUT) then
            print("[hop] Buscando servidores...")
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

        local nextServer = table.remove(cache, 1)
        if nextServer then
            teleportAttempts += 1
            print("[hop] Tentativa " .. teleportAttempts .. ": Teleportando para servidor " .. nextServer)
            
            local success, errorMsg = pcall(function()
                TeleportService:TeleportToPlaceInstance(targetPlaceId, nextServer, Players.LocalPlayer)
            end)
            
            if not success then
                warn("[hop] Erro no teleporte: " .. tostring(errorMsg))
            end
            
            -- Aguardar antes da próxima tentativa
            local waitTime = math.min(2 + (teleportAttempts * 0.5), 10) -- Backoff exponencial
            task.wait(waitTime)
        else
            -- Cache vazio, buscar mais servidores
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

-- Função para obter estatísticas
function module:GetStats()
    return {
        cachedServers = #cache,
        lastFetch = lastFetch,
        fallbackServers = #fallbackCache
    }
end

return module
