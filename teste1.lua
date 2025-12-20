local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

local PlaceID = game.PlaceId
local AllIDs = {}
local foundAnything = ""
local actualHour = os.date("!*t").hour
local Deleted = false

-- Nome único do arquivo por conta para evitar conflitos
local fileName = "NotSameServers_" .. LocalPlayer.UserId .. ".json"

-- Carregar histórico de servidores visitados
local function LoadHistory()
    local success, data = pcall(function()
        if readfile and isfile and isfile(fileName) then
            return HttpService:JSONDecode(readfile(fileName))
        end
        return {}
    end)
    
    if success then
        return data
    else
        return {actualHour}
    end
end

-- Salvar histórico de servidores visitados
local function SaveHistory()
    pcall(function()
        if writefile then
            writefile(fileName, HttpService:JSONEncode(AllIDs))
        end
    end)
end

-- Inicializar histórico
AllIDs = LoadHistory()

-- Limpar histórico se for de um dia diferente
if AllIDs[1] ~= actualHour then
    AllIDs = {actualHour}
    SaveHistory()
end

function TPReturner()
    local Site
    if foundAnything == "" then
        Site = HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100'))
    else
        Site = HttpService:JSONDecode(game:HttpGet('https://games.roblox.com/v1/games/' .. PlaceID .. '/servers/Public?sortOrder=Asc&limit=100&cursor=' .. foundAnything))
    end

    local ID = ""
    if Site.nextPageCursor and Site.nextPageCursor ~= "null" and Site.nextPageCursor ~= nil then
        foundAnything = Site.nextPageCursor
    end

    local serversChecked = 0
    local suitableServers = {}
    
    -- Coletar servidores adequados
    for i, v in pairs(Site.data) do
        local Possible = true
        ID = tostring(v.id)
        
        -- Verificar se o servidor tem vaga
        if tonumber(v.maxPlayers) > tonumber(v.playing) and tonumber(v.playing) > 0 then
            -- Verificar se não está no histórico
            for _, Existing in pairs(AllIDs) do
                if ID == tostring(Existing) then
                    Possible = false
                    break
                end
            end
            
            if Possible then
                table.insert(suitableServers, {
                    id = ID,
                    jobId = v.id,
                    playing = v.playing,
                    maxPlayers = v.maxPlayers
                })
            end
        end
        serversChecked = serversChecked + 1
    end

    -- Escolher um servidor aleatório da lista adequada
    if #suitableServers > 0 then
        local selectedServer = suitableServers[math.random(1, #suitableServers)]
        
        -- Adicionar ao histórico ANTES de teleportar
        table.insert(AllIDs, selectedServer.id)
        SaveHistory()
        
        print("Teleportando para servidor: " .. selectedServer.id)
        print("Jogadores: " .. selectedServer.playing .. "/" .. selectedServer.maxPlayers)
        
        -- Tentar teleportar
        local success, error = pcall(function()
            TeleportService:TeleportToPlaceInstance(PlaceID, selectedServer.jobId, LocalPlayer)
        end)
        
        if not success then
            print("Erro no teleporte: " .. tostring(error))
            -- Remover do histórico se falhou
            for i, savedId in ipairs(AllIDs) do
                if savedId == selectedServer.id then
                    table.remove(AllIDs, i)
                    break
                end
            end
            SaveHistory()
        end
        
        return true
    end
    
    return false
end

function Teleport()
    local attempts = 0
    local maxAttempts = 10
    
    while attempts < maxAttempts do
        local success = pcall(function()
            TPReturner()
            if foundAnything ~= "" then
                TPReturner()
            end
        end)
        
        if not success then
            print("Erro na tentativa " .. attempts)
        end
        
        attempts = attempts + 1
        wait(5) -- Esperar 5 segundos entre tentativas
    end
    
    print("Não foi possível encontrar um servidor adequado após " .. maxAttempts .. " tentativas")
end

-- Adicionar delay aleatório entre contas
print("Aguardando 1 segundo antes de iniciar...")
wait(2)

-- Iniciar o teleporte
Teleport()

-- Comandos de chat opcionais
LocalPlayer.Chatted:Connect(function(message)
    if message:lower() == "!rehop" then
        Teleport()
    elseif message:lower() == "!clearlist" then
        AllIDs = {actualHour}
        SaveHistory()
        print("Lista de servidores limpa!")
    end
end)
