wait(0.1)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- ===== CONFIGURAÇÃO =====
local PYTHON_SERVER_URL = "http://192.168.1.2:5000/webhook-filter"
local SERVER_SWITCH_INTERVAL = 3  -- Tempo entre trocas de servidor
local serverIdFormatted = "```" .. game.JobId .. "```"

-- ========= SISTEMA DE TROCA DE SERVIDOR =========
local LocalPlayer = Players.LocalPlayer
local PlaceID = game.PlaceId
local AllIDs = {}
local foundAnything = ""
local actualHour = os.date("!*t").hour

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
if AllIDs[1] ~= actualHour then
    AllIDs = {actualHour}
    SaveHistory()
end

local function TPReturner()
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
        
        print("🔄 Teleportando para servidor: " .. selectedServer.id)
        print("👥 Jogadores: " .. selectedServer.playing .. "/" .. selectedServer.maxPlayers)
        
        -- Tentar teleportar
        local success, error = pcall(function()
            TeleportService:TeleportToPlaceInstance(PlaceID, selectedServer.jobId, LocalPlayer)
        end)
        
        if not success then
            print("❌ Erro no teleporte: " .. tostring(error))
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

local function Teleport()
    local attempts = 0
    local maxAttempts = 10
    
    print("🔄 Iniciando busca por novo servidor...")
    
    while attempts < maxAttempts do
        local success = pcall(function()
            TPReturner()
            if foundAnything ~= "" then
                TPReturner()
            end
        end)
        
        if not success then
            print("❌ Erro na tentativa " .. attempts)
        end
        
        attempts = attempts + 1
        wait(5) -- Esperar 5 segundos entre tentativas
    end
    
    if attempts >= maxAttempts then
        print("⚠️ Não foi possível encontrar um servidor adequado após " .. maxAttempts .. " tentativas")
        return false
    end
    
    return true
end

-- ========= FORMATAÇÃO =========
local function fmtShort(n)
    if not n then return "0" end
    local a = math.abs(n)
    if a >= 1e12 then
        local s = string.format("%.2fT", n/1e12)
        return (s:gsub("%.00",""))
    elseif a >= 1e9 then
        local s = string.format("%.1fB", n/1e9)
        return s:gsub("%.0B","B")
    elseif a >= 1e6 then
        local s = string.format("%.1fM", n/1e6)
        return s:gsub("%.0M","M")
    elseif a >= 1e3 then
        return string.format("%.0fk", n/1e3)
    else
        return tostring(n)
    end
end

-- ===== FUNÇÃO ATUALIZADA PARA SCANEAR FASTOVERHEADTEMPLATE =====
local function scanAllFastOverheadTemplates()
    local allBrainrots = {}
    
    print("🔍 Iniciando scan do servidor (FastOverheadTemplate)...")
    
    -- Verificar se a pasta Debris existe
    local debrisFolder = Workspace:FindFirstChild("Debris")
    if not debrisFolder then
        print("❌ Pasta Debris não encontrada!")
        return {}
    end
    
    -- Contar quantos FastOverheadTemplate existem
    local templateCount = 0
    for _, item in pairs(debrisFolder:GetChildren()) do
        if item:IsA("Part") and item.Name == "FastOverheadTemplate" then
            templateCount = templateCount + 1
        end
    end
    
    print("📊 FastOverheadTemplate encontrados: " .. templateCount)
    
    -- Scanear cada FastOverheadTemplate
    local scannedCount = 0
    for _, template in pairs(debrisFolder:GetChildren()) do
        if template:IsA("Part") and template.Name == "FastOverheadTemplate" then
            scannedCount = scannedCount + 1
            
            print("🔎 Scan template " .. scannedCount)
            
            -- Procurar pela GUI dentro do template
            local gui = template:FindFirstChild("AnimalOverhead")
            if gui then
                print("   ✅ GUI encontrada")
                
                -- Tentar obter o nome do brainrot de DisplayName
                local brainrotName = "Unknown"
                local displayName = gui:FindFirstChild("DisplayName")
                if displayName and displayName:IsA("TextLabel") then
                    brainrotName = displayName.Text or "Unknown"
                    print("   📝 DisplayName: " .. brainrotName)
                else
                    print("   ❌ DisplayName não encontrado ou não é TextLabel")
                    -- Tentar encontrar DisplayName em outros lugares
                    for _, child in pairs(gui:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Name == "DisplayName" then
                            brainrotName = child.Text or "Unknown"
                            print("   📝 DisplayName (encontrado em descendentes): " .. brainrotName)
                            break
                        end
                    end
                end
                
                -- Tentar obter a geração do brainrot de Generation
                local genValue = 0
                local genText = "0/s"
                local generation = gui:FindFirstChild("Generation")
                if generation and generation:IsA("TextLabel") then
                    genText = generation.Text or "0/s"
                    print("   💰 Generation: " .. genText)
                else
                    print("   ❌ Generation não encontrado ou não é TextLabel")
                    -- Tentar encontrar Generation em outros lugares
                    for _, child in pairs(gui:GetDescendants()) do
                        if child:IsA("TextLabel") and child.Name == "Generation" then
                            genText = child.Text or "0/s"
                            print("   💰 Generation (encontrado em descendentes): " .. genText)
                            break
                        end
                    end
                end
                
                -- Converter texto para número
                if genText:find("/s") then
                    local cleanText = genText:gsub("%$", ""):gsub("/s", ""):gsub(" ", ""):gsub(",", "")
                    
                    -- Converter valores com k, M, B, T
                    if cleanText:find("T") then
                        local numStr = cleanText:gsub("T", "")
                        local num = tonumber(numStr)
                        if num then 
                            genValue = num * 1000000000000
                            print("   🔢 Convertido T: " .. numStr .. "T → " .. genValue)
                        end
                    elseif cleanText:find("B") then
                        local numStr = cleanText:gsub("B", "")
                        local num = tonumber(numStr)
                        if num then 
                            genValue = num * 1000000000
                            print("   🔢 Convertido B: " .. numStr .. "B → " .. genValue)
                        end
                    elseif cleanText:find("M") then
                        local numStr = cleanText:gsub("M", "")
                        local num = tonumber(numStr)
                        if num then 
                            genValue = num * 1000000
                            print("   🔢 Convertido M: " .. numStr .. "M → " .. genValue)
                        end
                    elseif cleanText:find("k") then
                        local numStr = cleanText:gsub("k", "")
                        local num = tonumber(numStr)
                        if num then 
                            genValue = num * 1000
                            print("   🔢 Convertido k: " .. numStr .. "k → " .. genValue)
                        end
                    else
                        genValue = tonumber(cleanText) or 0
                        print("   🔢 Número direto: " .. genValue)
                    end
                end
                
                -- Adicionar à lista se for válido
                if brainrotName ~= "Unknown" and genValue > 0 then
                    local brainrotInfo = {
                        name = brainrotName,
                        generation = genText,
                        valuePerSecond = genText,
                        numericGen = genValue,
                        templateId = scannedCount
                    }
                    
                    table.insert(allBrainrots, brainrotInfo)
                    print("    ✅ Template " .. scannedCount .. ": " .. brainrotName .. " - " .. genText .. " (Valor: " .. fmtShort(genValue) .. ")")
                else
                    if brainrotName == "Unknown" then
                        print("    ⚠️  Template " .. scannedCount .. ": Nome não encontrado")
                    end
                    if genValue <= 0 then
                        print("    ⚠️  Template " .. scannedCount .. ": Geração inválida (" .. genText .. ")")
                    end
                end
            else
                print("    ❌ Template " .. scannedCount .. ": GUI não encontrada")
            end
        end
    end
    
    -- Ordenar por geração (maior primeiro)
    table.sort(allBrainrots, function(a, b)
        return a.numericGen > b.numericGen
    end)
    
    -- Pegar os 5 MAIORES brainrots (ou menos se não houver 5)
    local topBrainrots = {}
    for i = 1, math.min(5, #allBrainrots) do
        table.insert(topBrainrots, allBrainrots[i])
    end
    
    print("✅ Scan completo! Total válidos: " .. #allBrainrots)
    print("🏆 Top " .. #topBrainrots .. " brainrots encontrados")
    
    return topBrainrots
end

-- ===== FUNÇÃO PARA OBTER DATA E HORA ATUAL =====
local function getCurrentDateTime()
    local dateTable = os.date("*t")
    return string.format("%02d/%02d/%04d %02d:%02d:%02d", 
        dateTable.day, dateTable.month, dateTable.year,
        dateTable.hour, dateTable.min, dateTable.sec)
end

-- ===== FUNÇÃO PARA DETERMINAR WEBHOOK BASEADO NO VALOR =====
local function getWebhookForValue(value)
    if not value then return nil, "LOW" end
    
    print("🎯 Classificando valor: " .. value .. " (" .. fmtShort(value) .. ")")
    
    if value >= 100000000 then -- 100M+
        print("💎 ULTRA_HIGH (100M+)")
        return "ULTRA_HIGH_WEBHOOK", "ULTRA_HIGH"
    elseif value >= 10000000 then -- 10M-99M
        print("🔥 SPECIAL (10M-99M)")
        return "SPECIAL_WEBHOOK", "SPECIAL"
    elseif value >= 1000000 then -- 1M-9M
        print("⭐ NORMAL (1M-9M)")
        return "NORMAL_WEBHOOK", "NORMAL"
    else
        print("📭 LOW")
        return nil, "LOW"
    end
end

-- ====== HELPER: envio robusto para o servidor Python ======
local function _sendToPythonServer(jsonBody)
    local success = false
    local responseData = nil
    
    local requestFunctions = {
        function() return syn and syn.request end,
        function() return http_request end,
        function() return request end,
        function() return http and http.request end
    }
    
    for _, getRequestFunc in ipairs(requestFunctions) do
        local req = getRequestFunc()
        if req then
            local ok, res = pcall(function()
                return req({
                    Url = PYTHON_SERVER_URL,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = jsonBody
                })
            end)
            
            if ok and res then
                local statusCode = tonumber(res.StatusCode or res.Status)
                if statusCode and statusCode < 400 then
                    success = true
                    if res.Body then
                        responseData = HttpService:JSONDecode(res.Body)
                    end
                    break
                else
                    print("❌ Erro no servidor Python: Status " .. tostring(statusCode))
                end
            end
        end
    end
    
    return success, responseData
end

-- ===== FUNÇÃO PRINCIPAL PARA ENVIAR TOP 5 BRAINROTS PARA O SERVIDOR PYTHON =====
local function sendTopBrainrotsToPython(topBrainrots)
    if not topBrainrots or #topBrainrots == 0 then
        print("📭 Nenhum brainrot qualificado encontrado")
        return
    end
    
    -- Determinar qual webhook usar baseado no MAIOR brainrot
    local highestBrainrot = topBrainrots[1]
    local webhookType, category = getWebhookForValue(highestBrainrot.numericGen)
    
    if not webhookType then
        print("❌ Brainrots não qualificados. Maior: " .. highestBrainrot.name .. " - " .. highestBrainrot.valuePerSecond)
        return
    end
    
    local currentDateTime = getCurrentDateTime()
    
    -- Construir descrição
    local description = ""
    for i, brainrot in ipairs(topBrainrots) do
        description = description .. string.format("**%dº** - %s: **%s**\n", i, brainrot.name, brainrot.valuePerSecond)
    end
    
    -- Preparar dados para enviar
    local embedData = {
        job_id = game.JobId,
        server_id = serverIdFormatted,
        place_id = tostring(game.PlaceId),
        players = #Players:GetPlayers(),
        max_players = Players.MaxPlayers,
        total_found = #topBrainrots,
        current_datetime = currentDateTime,
        webhook_type = webhookType,
        category = category,
        embed_info = {
            title = highestBrainrot.name,
            description = description,
            top_brainrots = topBrainrots,
            highest_brainrot = {
                name = highestBrainrot.name,
                value_per_second = highestBrainrot.valuePerSecond,
                numeric_gen = highestBrainrot.numericGen
            }
        }
    }
    
    local success, json = pcall(HttpService.JSONEncode, HttpService, embedData)
    
    if success then
        print("📤 Enviando dados para servidor Python...")
        print("📋 Job ID: " .. game.JobId)
        print("🎮 Jogadores: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers)
        print("📊 Categoria: " .. category)
        print("🔤 Server ID sendo enviado: " .. serverIdFormatted)
        
        local sendSuccess, response = _sendToPythonServer(json)
        
        if sendSuccess then
            if response and response.status == "sent" then
                print("✅ Embed enviado para Discord via Python!")
            elseif response and response.status == "duplicate" then
                print("📭 Servidor já foi enviado anteriormente (Job ID duplicado)")
            else
                print("✅ Dados enviados para servidor Python!")
            end
        else
            print("❌ Falha ao enviar para servidor Python")
        end
    else
        print("❌ Erro ao criar JSON")
    end
end

-- ===== FUNÇÃO PARA TROCAR DE SERVIDOR =====
local function switchServer()
    print("🔄 Iniciando troca de servidor...")
    
    local success = Teleport()
    
    if success then
        print("✅ Troca de servidor iniciada com sucesso")
        return true
    else
        print("❌ Falha na troca de servidor")
        return false
    end
end

-- ========= EXECUÇÃO PRINCIPAL =========
local function main()
    local consecutiveFailures = 0
    local maxConsecutiveFailures = 3
    
    print("🌐 Sistema iniciado!")
    print("🔗 Enviando para servidor Python: " .. PYTHON_SERVER_URL)
    print("🎯 Capturando os 5 MAIORES brainrots por servidor!")
    print("🔤 Server ID atual: " .. serverIdFormatted)
    print("📊 Histórico de servidores: " .. #AllIDs - 1)
    print("⏰ Troca automática a cada " .. SERVER_SWITCH_INTERVAL .. " segundos")
    
    -- Comandos de chat
    LocalPlayer.Chatted:Connect(function(message)
        if message:lower() == "!rehop" then
            print("🔄 Comando !rehop recebido, trocando de servidor...")
            switchServer()
        elseif message:lower() == "!clearlist" then
            AllIDs = {actualHour}
            SaveHistory()
            print("✅ Lista de servidores limpa!")
        elseif message:lower() == "!scan" then
            print("🔍 Comando !scan recebido, forçando scan...")
            local success, topBrainrots = pcall(scanAllFastOverheadTemplates)
            if success then
                sendTopBrainrotsToPython(topBrainrots)
            end
        elseif message:lower() == "!status" then
            print("📊 Status do sistema:")
            print("   Server ID atual: " .. serverIdFormatted)
            print("   Servidores visitados: " .. #AllIDs - 1)
            print("   Jogadores no servidor: " .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers)
            print("   Próxima troca automática: em " .. SERVER_SWITCH_INTERVAL .. "s")
        end
    end)
    
    while true do
        print("\n" .. string.rep("=", 50))
        print("🔄 INICIANDO NOVO CICLO - " .. os.date("%X"))
        print("🔤 Server ID: " .. serverIdFormatted)
        print(string.rep("=", 50))
        
        wait(3)
        
        -- Fazer scan dos brainrots
        local success, topBrainrots = pcall(scanAllFastOverheadTemplates)
        
        if success then
            sendTopBrainrotsToPython(topBrainrots)
            consecutiveFailures = 0
        else
            print("❌ Erro no scan: " .. tostring(topBrainrots))
            consecutiveFailures = consecutiveFailures + 1
        end
        
        -- Aguardar intervalo configurado
        print("⏳ Aguardando " .. SERVER_SWITCH_INTERVAL .. " segundos...")
        wait(SERVER_SWITCH_INTERVAL)
        
        if consecutiveFailures >= maxConsecutiveFailures then
            print("⚠️ Muitas falhas consecutivas, forçando troca de servidor...")
            consecutiveFailures = 0
        end
        
        -- Trocar de servidor
        print("🔄 Iniciando troca automática de servidor...")
        local switchSuccess = switchServer()
        
        if switchSuccess then
            print("✅ Troca de servidor iniciada!")
            -- O script será reiniciado após teleporte
            break
        else
            print("❌ Falha na troca, tentando novamente em 3s")
            wait(3)
        end
    end
end

coroutine.wrap(main)()
