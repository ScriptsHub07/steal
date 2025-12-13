wait(0.1)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- ===== WEBHOOKS =====
local WEBHOOK_URL = "https://discord.com/api/webhooks/1449187894211383367/fzRzIXVIB0e8tPzyUTaKaxCGh52MDhOj51uBl5tH204md4l-0BSe-sFGwYoiiXFd-k7r"
local SPECIAL_WEBHOOK_URL = "https://discord.com/api/webhooks/1449198265571741881/kkEs6wbKv-Fy6E8RbHP6Kd1HKpYQ0CE57tFDvjtd3ZtySoaJj55TWLdKMzbWTUV5f5Eu"
local ULTRA_HIGH_WEBHOOK_URL = "https://discord.com/api/webhooks/1449194776061808691/M1toyE1c9R3s72_AbHfNPbVEV4WPj2tusrCWY0h5xxk3LWKdefsSdx2V_yDGp9v7goVS"
local BRAINROT_150M_WEBHOOK_URL = "https://discord.com/api/webhooks/1449195959350202520/8fEMni7EefAQ7du6_2yIB6faOJ2AiO6zlyH2-odXPMHSru7W4f9z6UzE0kf34d_3mbvy"


local REDIRECTOR_BASE_URL = "https://lustrous-tiramisu-f16cde.netlify.app"

-- ===== CONFIGURAÇÃO =====
local SERVER_SWITCH_INTERVAL = 2
local serverIdFormatted = "``" .. game.JobId .. "``"
-- ===== VARIÁVEL PARA EVITAR DUPLICATAS =====
local sentServers = {}
local sentBrainrot150MServers = {} -- Nova tabela para controlar servidores com brainrot > 150M

-- ===== MÓDULO DE SERVER HOP CORRIGIDO =====
local function createHopModule()
    local HopModule = {}
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

    function HopModule:Teleport(placeId)
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
    function HopModule:ClearUsedServers()
        usedServers = {}
        print("[hop] Lista de servidores usados foi limpa")
    end

    return HopModule
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

-- ===== FUNÇÃO PARA OBTER TODAS AS PLOTS =====
local function getAllPlots()
    local plots = {}
    
    local plotsFolder = Workspace:FindFirstChild("Plots")
    if plotsFolder then
        for _, plot in pairs(plotsFolder:GetChildren()) do
            if plot:FindFirstChild("AnimalPodiums") then
                table.insert(plots, plot)
            end
        end
    end
    
    for _, obj in pairs(Workspace:GetChildren()) do
        if obj.Name:find("Plot") or obj.Name:find("plot") then
            if not table.find(plots, obj) and obj:FindFirstChild("AnimalPodiums") then
                table.insert(plots, obj)
            end
        end
    end
    
    return plots
end

-- ===== FUNÇÃO CORRIGIDA PARA CONVERTER APENAS VALORES VÁLIDOS =====
local function textToNumber(text)
    if not text then return 0 end
    
    print("🔍 Analisando: '" .. tostring(text) .. "'")
    
    -- Verificar se é um formato válido de geração (deve ter /s ou k/M/B)
    local hasValidFormat = text:find("/s") or text:find("k") or text:find("M") or text:find("B") or text:find("T")
    if not hasValidFormat then
        print("❌ Formato inválido para geração")
        return 0
    end
    
    -- Limpar o texto
    local cleanText = tostring(text):gsub("%$", ""):gsub("/s", ""):gsub(" ", ""):gsub(",", "")
    
    print("🔍 Texto limpo: '" .. cleanText .. "'")
    
    -- Verificar padrões na ordem de prioridade (do maior para o menor)
    
    -- 1. Padrão com "T" (Trilhões)
    if cleanText:find("T") then
        local numStr = cleanText:gsub("T", "")
        local num = tonumber(numStr)
        if num then
            local result = num * 1000000000000
            print("💰 Convertido T: " .. numStr .. "T → " .. result)
            return result
        end
    end
    
    -- 2. Padrão com "B" (Bilhões)
    if cleanText:find("B") then
        local numStr = cleanText:gsub("B", "")
        local num = tonumber(numStr)
        if num then
            local result = num * 1000000000
            print("💰 Convertido B: " .. numStr .. "B → " .. result)
            return result
        end
    end
    
    -- 3. Padrão com "M" (Milhões)
    if cleanText:find("M") then
        local numStr = cleanText:gsub("M", "")
        local num = tonumber(numStr)
        if num then
            local result = num * 1000000
            print("💰 Convertido M: " .. numStr .. "M → " .. result)
            return result
        end
    end
    
    -- 4. Padrão com "k" (Milhares)
    if cleanText:find("k") then
        local numStr = cleanText:gsub("k", "")
        local num = tonumber(numStr)
        if num then
            local result = num * 1000
            print("💰 Convertido k: " .. numStr .. "k → " .. result)
            return result
        end
    end
    
    -- 5. Se chegou aqui e tem /s, tentar número direto
    if text:find("/s") then
        local num = tonumber(cleanText)
        if num then
            print("💰 Número direto com /s: " .. num)
            return num
        end
    end
    
    print("❌ Não foi possível converter valor de geração")
    return 0
end

-- ===== FUNÇÃO MELHORADA PARA ENCONTRAR APENAS GERAÇÕES REAIS =====
local function getBrainrotGeneration(animalOverhead)
    if not animalOverhead then return 0, "0" end
    
    -- PRIMEIRO: Procurar apenas pelo label "Generation" (mais confiável)
    local generationLabel = animalOverhead:FindFirstChild("Generation")
    if generationLabel and generationLabel:IsA("TextLabel") and generationLabel.Text and generationLabel.Text ~= "" then
        local text = generationLabel.Text
        print("🏷️ Label 'Generation' encontrado: '" .. text .. "'")
        
        local numericValue = textToNumber(text)
        if numericValue > 0 then
            print("✅ Geração real encontrada: " .. text .. " → " .. numericValue)
            return numericValue, text
        end
    end
    
    -- SEGUNDO: Procurar por "ValuePerSecond" 
    local valueLabel = animalOverhead:FindFirstChild("ValuePerSecond")
    if valueLabel and valueLabel:IsA("TextLabel") and valueLabel.Text and valueLabel.Text ~= "" then
        local text = valueLabel.Text
        print("🏷️ Label 'ValuePerSecond' encontrado: '" .. text .. "'")
        
        local numericValue = textToNumber(text)
        if numericValue > 0 then
            print("✅ Valor por segundo encontrado: " .. text .. " → " .. numericValue)
            return numericValue, text
        end
    end
    
    -- TERCEIRO: Procurar por "GPS" 
    local gpsLabel = animalOverhead:FindFirstChild("GPS")
    if gpsLabel and gpsLabel:IsA("TextLabel") and gpsLabel.Text and gpsLabel.Text ~= "" then
        local text = gpsLabel.Text
        print("🏷️ Label 'GPS' encontrado: '" .. text .. "'")
        
        local numericValue = textToNumber(text)
        if numericValue > 0 then
            print("✅ GPS encontrado: " .. text .. " → " .. numericValue)
            return numericValue, text
        end
    end
    
    -- QUARTO: Procurar por "MoneyPerSecond"
    local moneyLabel = animalOverhead:FindFirstChild("MoneyPerSecond")
    if moneyLabel and moneyLabel:IsA("TextLabel") and moneyLabel.Text and moneyLabel.Text ~= "" then
        local text = moneyLabel.Text
        print("🏷️ Label 'MoneyPerSecond' encontrado: '" .. text .. "'")
        
        local numericValue = textToNumber(text)
        if numericValue > 0 then
            print("✅ MoneyPerSecond encontrado: " .. text .. " → " .. numericValue)
            return numericValue, text
        end
    end
    
    -- NÃO procurar em labels genéricos para evitar falsos positivos
    print("❌ Nenhum label de geração válido encontrado")
    return 0, "0"
end

-- ===== FUNÇÃO PRINCIPAL DE SCAN =====
local function scanAllPlots()
    local allBrainrots = {}
    
    print("🔍 Iniciando scan do servidor...")
    local plots = getAllPlots()
    
    print("📊 Plots encontradas: " .. #plots)
    
    for _, plot in pairs(plots) do
        local animalPodiums = plot:FindFirstChild("AnimalPodiums")
        if animalPodiums then
            for i = 1, 20 do
                local success, errorMsg = pcall(function()
                    local podium = animalPodiums:FindFirstChild(tostring(i))
                    if podium then
                        local base = podium:FindFirstChild("Base")
                        if base then
                            local spawn = base:FindFirstChild("Spawn")
                            if spawn then
                                local attachment = spawn:FindFirstChild("Attachment")
                                if attachment then
                                    local animalOverhead = attachment:FindFirstChild("AnimalOverhead")
                                    if animalOverhead then
                                        local brainrotName = "Unknown"
                                        local displayName = animalOverhead:FindFirstChild("DisplayName")
                                        if displayName and displayName:IsA("TextLabel") then
                                            brainrotName = displayName.Text or "Unknown"
                                        end
                                        
                                        local genValue, genText = getBrainrotGeneration(animalOverhead)
                                        
                                        -- VALIDAÇÃO ADICIONAL: só aceitar se for um valor realista
                                        if brainrotName ~= "Unknown" and brainrotName ~= "" and genValue > 0 then
                                            -- Verificar se o valor é realista (não muito alto para evitar falsos positivos)
                                            if genValue <= 1000000000000 then -- Máximo 1T (evitar valores absurdos)
                                                local brainrotInfo = {
                                                    name = brainrotName,
                                                    generation = genText,
                                                    valuePerSecond = genText,
                                                    numericGen = genValue
                                                }
                                                
                                                table.insert(allBrainrots, brainrotInfo)
                                                print("    ✅ " .. brainrotName .. " - " .. genText .. " (Valor: " .. genValue .. ")")
                                            else
                                                print("    ⚠️ " .. brainrotName .. " - VALOR MUITO ALTO (possível falso positivo): " .. genValue)
                                            end
                                        else
                                            print("    ⚠️ " .. brainrotName .. " - SEM GERAÇÃO VÁLIDA")
                                        end
                                    end
                                end
                            end
                        end
                    end
                end)
                
                if not success then
                    print("    ❌ ERRO no podium " .. i .. ": " .. tostring(errorMsg))
                end
            end
        end
    end
    
    -- Ordenar por geração (maior primeiro)
    table.sort(allBrainrots, function(a, b)
        return a.numericGen > b.numericGen
    end)
    
    -- Pegar apenas o MAIOR brainrot
    local highestBrainrot = allBrainrots[1] or nil
    
    print("✅ Scan completo! Total válidos: " .. #allBrainrots)
    
    return highestBrainrot
end

-- ====== FUNÇÃO PARA GERAR HTML EM BASE64 (SOLUÇÃO ALTERNATIVA) ======
local function generateBase64Redirector(placeId, gameInstanceId, brainrotInfo)
    -- Criar HTML simples com redirecionamento
    local html = string.format([[
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Join Roblox Server</title>
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            padding: 50px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            display: flex;
            flex-direction: column;
            justify-content: center;
            align-items: center;
        }
        .container {
            background: rgba(255, 255, 255, 0.1);
            backdrop-filter: blur(10px);
            border-radius: 20px;
            padding: 30px;
            box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
            max-width: 500px;
            width: 90%%;
        }
        h1 { font-size: 2em; margin-bottom: 20px; }
        .info {
            background: rgba(255, 255, 255, 0.2);
            border-radius: 10px;
            padding: 15px;
            margin: 15px 0;
        }
        .button {
            background: #4CAF50;
            color: white;
            border: none;
            padding: 15px 30px;
            font-size: 1.2em;
            border-radius: 10px;
            cursor: pointer;
            margin: 20px 0;
            text-decoration: none;
            display: inline-block;
        }
        .button:hover { background: #45a049; }
    </style>
    <script>
        window.onload = function() {
            const params = new URLSearchParams(window.location.search);
            const placeId = "%s";
            const gameInstanceId = "%s";
            const brainrotName = "%s";
            const generation = "%s";
            
            document.getElementById('brainrotName').textContent = brainrotName;
            document.getElementById('generation').textContent = generation;
            
            if (placeId && gameInstanceId) {
                // Tentar abrir no app Roblox
                const robloxUrl = 'roblox://placeID=' + placeId + '&gameInstanceId=' + gameInstanceId;
                const webUrl = 'https://www.roblox.com/games/' + placeId + '?gameInstanceId=' + gameInstanceId;
                
                document.getElementById('joinBtn').onclick = function() {
                    window.location.href = robloxUrl;
                    setTimeout(function() {
                        window.open(webUrl, '_blank');
                    }, 1000);
                };
                
                // Redirecionar automaticamente após 3 segundos
                setTimeout(function() {
                    window.location.href = robloxUrl;
                }, 3000);
            }
        };
    </script>
</head>
<body>
    <div class="container">
        <h1>🚀 Join Roblox Server</h1>
        <div class="info">
            <h3>Brainrot Detected:</h3>
            <h2 id="brainrotName">Loading...</h2>
            <p id="generation">0/s</p>
        </div>
        <p>Redirecting to Roblox...</p>
        <button id="joinBtn" class="button">🎮 JOIN NOW</button>
        <p><small>Auto-redirect in 3 seconds...</small></p>
    </div>
</body>
</html>
    ]], placeId, gameInstanceId, 
       brainrotInfo and brainrotInfo.name or "Unknown", 
       brainrotInfo and brainrotInfo.valuePerSecond or "0/s")
    
    -- Converter para Base64 (formato URL seguro)
    return game:GetService("HttpService"):Base64Encode(html)
end

-- ====== FUNÇÃO PARA GERAR LINK DE JOIN ======
local function generateJoinLink(brainrotInfo)
    local placeId = game.PlaceId
    local gameInstanceId = game.JobId
    
    if not placeId or not gameInstanceId then
        return nil
    end
    
    -- Método 1: Usar redirector externo (se configurado)
    if REDIRECTOR_BASE_URL ~= "" and REDIRECTOR_BASE_URL ~= "https://seu-usuario.github.io/redirector" then
        local params = {
            placeId = placeId,
            gameInstanceId = gameInstanceId,
            brainrotName = brainrotInfo and brainrotInfo.name or "Unknown",
            generation = brainrotInfo and brainrotInfo.valuePerSecond or "0/s"
        }
        
        local queryString = ""
        for key, value in pairs(params) do
            if queryString ~= "" then
                queryString = queryString .. "&"
            end
            queryString = queryString .. key .. "=" .. HttpService:UrlEncode(tostring(value))
        end
        
        return {
            direct = REDIRECTOR_BASE_URL .. "?" .. queryString,
            roblox = string.format("roblox://placeID=%d&gameInstanceId=%s", placeId, gameInstanceId),
            web = string.format("https://www.roblox.com/games/%d?gameInstanceId=%s", placeId, gameInstanceId)
        }
    end
    
    -- Método 2: Usar data URLs (funciona em navegadores modernos)
    local htmlBase64 = generateBase64Redirector(placeId, gameInstanceId, brainrotInfo)
    local dataUrl = "data:text/html;base64," .. htmlBase64
    
    return {
        direct = dataUrl,
        roblox = string.format("roblox://placeID=%d&gameInstanceId=%s", placeId, gameInstanceId),
        web = string.format("https://www.roblox.com/games/%d?gameInstanceId=%s", placeId, gameInstanceId),
        note = "Data URL funciona em navegadores modernos"
    }
end

-- ====== HELPER: envio robusto da webhook ======
local function _tryWebhookSend(jsonBody, webhookUrl)
    local success = false
    
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
                    Url = webhookUrl,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = jsonBody
                })
            end)
            
            if ok and res and (res.StatusCode or res.Status) and tonumber(res.StatusCode or res.Status) < 400 then
                success = true
                break
            end
        end
    end
    
    return success
end

-- ===== FUNÇÃO PARA DETERMINAR WEBHOOK BASEADO NO VALOR =====
local function getWebhookForValue(value)
    if not value then return nil, "LOW" end
    
    print("🎯 Classificando valor: " .. value .. " (" .. fmtShort(value) .. ")")
    
    if value >= 100000000 then -- 100M+
        print("💎 ULTRA_HIGH (100M+)")
        return ULTRA_HIGH_WEBHOOK_URL, "ULTRA_HIGH"
    elseif value >= 10000000 then -- 10M-99M
        print("🔥 SPECIAL (10M-99M)")
        return SPECIAL_WEBHOOK_URL, "SPECIAL"
    elseif value >= 1000000 then -- 1M-9M
        print("⭐ NORMAL (1M-9M)")
        return WEBHOOK_URL, "NORMAL"
    else
        print("📭 LOW")
        return nil, "LOW"
    end
end

-- ===== FUNÇÃO PARA VERIFICAR SE O SERVIDOR JÁ FOI ENVIADO =====
local function wasServerAlreadySent()
    local key = game.JobId
    return sentServers[key] == true
end

-- ===== FUNÇÃO PARA VERIFICAR SE O SERVIDOR JÁ FOI ENVIADO PARA BRAINROT 150M =====
local function wasBrainrot150MAlreadySent()
    local key = game.JobId
    return sentBrainrot150MServers[key] == true
end

-- ===== FUNÇÃO PARA MARCAR SERVIDOR COMO ENVIADO =====
local function markServerAsSent()
    local key = game.JobId
    sentServers[key] = true
end

-- ===== FUNÇÃO PARA MARCAR SERVIDOR COMO ENVIADO PARA BRAINROT 150M =====
local function markBrainrot150MAsSent()
    local key = game.JobId
    sentBrainrot150MServers[key] = true
end

-- ===== FUNÇÃO PARA OBTER DATA E HORA ATUAL =====
local function getCurrentDateTime()
    local dateTable = os.date("*t")
    return string.format("%02d/%02d/%04d %02d:%02d:%02d", 
        dateTable.day, dateTable.month, dateTable.year,
        dateTable.hour, dateTable.min, dateTable.sec)
end

-- ===== NOVA FUNÇÃO: ENVIAR NOTIFICAÇÃO ESPECIAL PARA BRAINROT > 150M =====
local function sendBrainrot150MNotification(highestBrainrot)
    if wasBrainrot150MAlreadySent() then
        print("📭 Servidor já enviado para brainrot 150M: " .. game.JobId)
        return
    end
    
    if not highestBrainrot or highestBrainrot.numericGen < 150000000 then
        return -- Só envia se for maior que 150M
    end
    
    local currentDateTime = getCurrentDateTime()
    
    -- Gerar link de join
    local joinLinks = generateJoinLink(highestBrainrot)
    
    -- Embed especial para brainrot > 150M
    local embed = {
        title = "👑 " .. highestBrainrot.name,
        description = "🚨 **Brainrot com mais de 150M de geração detectado!** 🚨",
        color = 16711680, -- Vermelho
        fields = {
            {
                name = "📊 Geração",
                value = "**" .. highestBrainrot.valuePerSecond .. "/s**",
                inline = true
            },
            {
                name = "👥 Jogadores no Servidor",
                value = "**" .. #Players:GetPlayers() .. "/" .. Players.MaxPlayers .. "**",
                inline = true
            },
            {
                name = "🕐 Detecção",
                value = "**" .. currentDateTime .. "**",
                inline = true
            }
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        footer = {
            text = "ALERTA BRAINROT 150M+ • Scanner Automático"
        }
    }

    local payload = {
        embeds = {embed}
    }
    
    local success, json = pcall(HttpService.JSONEncode, HttpService, payload)
    
    if success then
        print("🚨 ENVIANDO ALERTA BRAINROT 150M+!")
        print("👑 " .. highestBrainrot.name .. " - " .. highestBrainrot.valuePerSecond .. " (Valor: " .. highestBrainrot.numericGen .. ")")
        print("🔗 Link Roblox: " .. (joinLinks and joinLinks.roblox or "N/A"))
        
        local sendSuccess = _tryWebhookSend(json, BRAINROT_150M_WEBHOOK_URL)
        if sendSuccess then
            markBrainrot150MAsSent()
            print("✅ Alerta brainrot 150M+ enviado com sucesso!")
        else
            print("❌ Falha no envio do alerta brainrot 150M+")
        end
    else
        print("❌ Erro ao criar JSON para alerta brainrot 150M")
    end
end

-- ===== ENVIO DE UM ÚNICO EMBED POR SERVIDOR =====
local function sendHighestBrainrotWebhook(highestBrainrot)
    if wasServerAlreadySent() then
        print("📭 Servidor já enviado: " .. game.JobId)
        return
    end
    
    if not highestBrainrot then
        print("📭 Nenhum brainrot qualificado encontrado")
        return
    end
    
    -- VERIFICAR E ENVIAR NOTIFICAÇÃO PARA BRAINROT > 150M
    if highestBrainrot.numericGen >= 150000000 then
        sendBrainrot150MNotification(highestBrainrot)
    end
    
    local webhookUrl, category = getWebhookForValue(highestBrainrot.numericGen)
    
    if not webhookUrl then
        print("❌ Brainrot não qualificado: " .. highestBrainrot.name .. " - " .. highestBrainrot.valuePerSecond)
        return
    end
    
    -- Gerar link de join
    local joinLinks = generateJoinLink(highestBrainrot)
    
    -- Informações da categoria
    local categoryInfo = {
        ULTRA_HIGH = {color = 10181046, emoji = "💎", name = "ULTRA HIGH"},
        SPECIAL = {color = 16766720, emoji = "🔥", name = "ESPECIAL"}, 
        NORMAL = {color = 5793266, emoji = "⭐", name = "NORMAL"}
    }
    
    local info = categoryInfo[category]
    local currentDateTime = getCurrentDateTime()
    
    -- Embed único com apenas o maior brainrot
    local embed = {
        title = info.emoji .. " " .. highestBrainrot.name,
        description = "",
        color = info.color,
        fields = {
            {
                name = "📊 Geração",
                value = "**" .. highestBrainrot.valuePerSecond .. "/s**",
                inline = true
            },
            {
                name = "🌐 Informações do Servidor",
                value = string.format("**Jogadores:** %d/%d\n**Server ID:** `%s`",
                    #Players:GetPlayers(), Players.MaxPlayers,
                    serverIdFormatted),
                inline = false
            }
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        footer = {
            text = "Scanner Automático • " .. info.name .. " • " .. currentDateTime
        }
    }

    -- Payload com apenas um embed
    local payload = {
        embeds = {embed}
    }
    
    local success, json = pcall(HttpService.JSONEncode, HttpService, payload)
    
    if success then
        print("📤 Enviando maior brainrot para " .. category .. " webhook")
        print("👑 " .. highestBrainrot.name .. " - " .. highestBrainrot.valuePerSecond)
        print("🔗 Link Roblox: " .. (joinLinks and joinLinks.roblox or "N/A"))
        
        local sendSuccess = _tryWebhookSend(json, webhookUrl)
        if sendSuccess then
            markServerAsSent()
            print("✅ Embed do servidor enviado com sucesso!")
        else
            print("❌ Falha no envio do embed")
        end
    else
        print("❌ Erro ao criar JSON")
    end
end

-- ===== SISTEMA MELHORADO DE TROCA DE SERVIDOR =====
local function switchServer()
    print("🔄 Iniciando troca de servidor...")
    
    -- Método 1: Server Hop local (corrigido)
    local success, errorMsg = pcall(function()
        local hopModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/ScriptsHub07/steal/refs/heads/main/teste1.lua"))()
        hopModule:Teleport()
    end)
    
    if success then
        print("✅ Server Hop executado com sucesso")
        return true
    else
        print("❌ Falha no Server Hop: " .. tostring(errorMsg))
    end
    
    -- Método 2: TeleportService direto
    local success2, errorMsg2 = pcall(function()
        TeleportService:Teleport(game.PlaceId)
    end)
    
    if success2 then
        print("✅ TeleportService executado com sucesso")
        return true
    else
        print("❌ Falha no TeleportService: " .. tostring(errorMsg2))
    end
    
    print("⚠️ Todos os métodos falharam, aguardando e tentando novamente...")
    wait(5)
    return false
end

-- ========= EXECUÇÃO PRINCIPAL =========
local function main()
    local consecutiveFailures = 0
    local maxConsecutiveFailures = 3
    
    print("🌐 Sistema de links ativado!")
    if REDIRECTOR_BASE_URL ~= "" and REDIRECTOR_BASE_URL ~= "https://seu-usuario.github.io/redirector" then
        print("🔗 Usando redirector externo")
    else
        print("📄 Usando Data URLs para redirecionamento")
        print("ℹ️ Nota: Configure REDIRECTOR_BASE_URL para usar um servidor externo")
    end
    
    wait(1)
    
    while true do
        print("\n" .. string.rep("=", 50))
        print("🔄 INICIANDO NOVO SCAN - " .. os.date("%X"))
        print(string.rep("=", 50))
        
        wait(3)
        
        local success, highestBrainrot = pcall(scanAllPlots)
        
        if success then
            sendHighestBrainrotWebhook(highestBrainrot)
            consecutiveFailures = 0
        else
            print("❌ Erro no scan")
            consecutiveFailures = consecutiveFailures + 1
        end
        
        if SERVER_SWITCH_INTERVAL > 0 then
            wait(2)
            
            -- Verificar se atingiu muitas falhas consecutivas
            if consecutiveFailures >= maxConsecutiveFailures then
                print("⚠️ Muitas falhas consecutivas, reiniciando o ciclo...")
                consecutiveFailures = 0
                wait(5)
            end
            
            print("🔄 Trocando de servidor...")
            local switchSuccess = switchServer()
            
            if switchSuccess then
                print("✅ Troca de servidor iniciada com sucesso")
                consecutiveFailures = 0
            else
                print("❌ Falha na troca de servidor")
                consecutiveFailures = consecutiveFailures + 1
            end
            
            -- Esperar a teleportação acontecer
            print("⏳ Aguardando teleportação...")
            wait(5)
        else
            print("⏸️  Troca de servidor desativada")
            break
        end
    end
end

print("✅ Sistema iniciado!")

coroutine.wrap(main)()
