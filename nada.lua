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
    local url = "https://games.roblox.com/v1/games/"..PLACE_ID.."/servers/Public?sortOrder=Asc&limit=100"
    local ok, data = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(url))
    end)
    if ok and data and data.data then
        for _,v in pairs(data.data) do
            local playing = tonumber(v.playing)
            local maxPlayers = tonumber(v.maxPlayers)
            
            -- Filtra servidores com entre 5 e 6 jogadores (máximo 8)
            if playing >= 5 and playing <= 6 and maxPlayers == 8 then
                table.insert(servers, {
                    id = v.id,
                    playing = playing
                })
            end
        end
        
        -- Ordena por quantidade de jogadores (mais próximos de 6 primeiro)
        table.sort(servers, function(a, b)
            return a.playing > b.playing
        end)
    end
    return servers
end

function module:Teleport(placeId)
    while true do
        if #cache == 0 or (tick() - lastFetch > CACHE_TIMEOUT) then
            cache = fetchServers()
            lastFetch = tick()
            
            if #cache == 0 then
                warn("[hop] Nenhum servidor com 5-6 jogadores encontrado, aguardando para tentar novamente.")
                wait(10)
            else
                print("[hop] Encontrados "..#cache.." servidores com 5-6 jogadores")
            end
        end

        local nextServer = table.remove(cache, 1)
        if nextServer then
            print("[hop] Teleportando para servidor com "..nextServer.playing.." jogadores: "..nextServer.id)
            TeleportService:TeleportToPlaceInstance(placeId or PLACE_ID, nextServer.id, Players.LocalPlayer)
            wait(2) 
        else
            wait(6)
        end
    end
end

return module
