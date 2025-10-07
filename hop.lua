local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local module = {}
local cache = {}
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
        
        -- Adicionar cursor para paginação se existir
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
                
                if tonumber(v.maxPlayers) > tonumber(v.playing) then
                    table.insert(servers, v.id)
                    serversFetched = serversFetched + 1
                end
            end
            
            -- Verificar se há mais páginas
            if data.nextPageCursor and serversFetched < maxServers then
                cursor = data.nextPageCursor
            else
                break
            end
        else
            break
        end
        
        wait(0.5) -- Pequena pausa entre requisições para evitar rate limiting
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
            print("[hop] Teleportando para servidor: "..nextServer)
            TeleportService:TeleportToPlaceInstance(placeId or PLACE_ID, nextServer, Players.LocalPlayer)
            wait(2) 
        else
            wait(6)
        end
    end
end

return module
