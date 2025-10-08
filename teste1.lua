local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local module = {}
local cache = {}
local usedServers = {} -- Tabela para rastrear servidores já utilizados
local lastFetch = 0
local CACHE_TIMEOUT = 60
local PLACE_ID = game.PlaceId

local function fetchServers()
    local servers = {}
    local cursor = ""
    local serversFetched = 0
    local maxServers = 300
    
    while serversFetched < maxServers do
        local url = "https://games.roblox.com/v1/games/"..PLACE_ID.."/servers/Public?sortOrder=Asc&limit=100"
        
        if cursor ~= "" then
            url = url .. "&cursor=" .. cursor
        end
        
        local ok, data = pcall(function()
            return HttpService:JSONDecode(game:HttpGet(url))
        end)
        
        if ok and data and data.data then
            for _, v in pairs(data.data) do
                if serversFetched >= maxServers then
                    break
                end
                
                -- Verificar se o servidor não está sendo usado e tem vaga
                if tonumber(v.maxPlayers) > tonumber(v.playing) and not usedServers[v.id] then
                    table.insert(servers, v.id)
                    serversFetched = serversFetched + 1
                end
            end
            
            if data.nextPageCursor and serversFetched < maxServers then
                cursor = data.nextPageCursor
            else
                break
            end
        else
            break
        end
        
        wait(0.5)
    end
    
    return servers
end

function module:Teleport(placeId)
    while true do
        if #cache == 0 or (tick() - lastFetch > CACHE_TIMEOUT) then
            cache = fetchServers()
            lastFetch = tick()
            if #cache == 0 then
                warn("[hop] Nenhum servidor encontrado, aguardando para tentar novamente.")
                wait(10)
            else
                print("[hop] Encontrados " .. #cache .. " servidores disponíveis")
            end
        end

        local nextServer = table.remove(cache, 1)
        if nextServer then
            -- Marcar servidor como usado
            usedServers[nextServer] = true
            
            -- Limpar servidores usados após um tempo para evitar acumulação
            for serverId, _ in pairs(usedServers) do
                if tick() - lastFetch > CACHE_TIMEOUT * 2 then
                    usedServers[serverId] = nil
                end
            end
            
            print("[hop] Teleportando para servidor: "..nextServer)
            
            local success, error = pcall(function()
                TeleportService:TeleportToPlaceInstance(placeId or PLACE_ID, nextServer, Players.LocalPlayer)
            end)
            
            if not success then
                warn("[hop] Erro ao teleportar: "..tostring(error))
                -- Se falhar, liberar o servidor para uso novamente
                usedServers[nextServer] = nil
            end
            
            wait(2) 
        else
            wait(6)
        end
    end
end

-- Função para limpar servidores usados manualmente
function module:ClearUsedServers()
    usedServers = {}
    print("[hop] Lista de servidores usados foi limpa")
end

return module
