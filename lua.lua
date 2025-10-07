wait(0.1)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local HttpService = game:GetService("HttpService")
local TeleportService = game:GetService("TeleportService")

-- ===== WEBHOOKS =====
local WEBHOOK_URL = "https://discord.com/api/webhooks/1424416294022807563/4zIQ6lind854v4kDzt7eHczFDuWcYUQ-M7NQQ9ZCP4jxD8uXjFGleIVAHi0IIAhDd2r-"
local SPECIAL_WEBHOOK_URL = "https://discord.com/api/webhooks/1424416367431516311/mg-l7iEF9Xk3RFiVF-YKrFDL8JSVjXAFVFnNvuJ7x1nmZ2xMP9_1zIHJ9hJbuOmY4fGi"
local ULTRA_HIGH_WEBHOOK_URL = "https://discord.com/api/webhooks/1424908273370529964/m17LNlQG1Nx33EzYZIcDePP7KsGT59teViuwybrMpFBxQHJPD1EglcB3z2Ye0qzlvKA7"
local BRAINROT_150M_WEBHOOK_URL = "https://discord.com/api/webhooks/1424416592011464726/tQtnmJdAgKNSMX1bkAp8PdP9pws6bvoXKMwJWlPc0wkx2McMv4zmxwL6M9Pnw-VlOMEZ"

-- ===== CONFIGURAÇÃO =====
local SERVER_SWITCH_INTERVAL = 2

-- ===== VARIÁVEL PARA EVITAR DUPLICATAS =====
local sentServers = {}
local sentBrainrot150MServers = {} -- Nova tabela para controlar servidores com brainrot > 150M

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
                name = "💰 Valor Numérico",
                value = "**" .. fmtShort(highestBrainrot.numericGen) .. "**",
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
        title = "👑 " .. highestBrainrot.name,
        description = "",
        color = info.color,
        fields = {
            {
                name = "📊 Geração",
                value = "**" .. highestBrainrot.valuePerSecond .. "/s**",
                inline = false
            },
            {
                name = "🌐 Informações do Servidor",
                value = string.format("**Job ID:** ```%s```\n**Jogadores:** %d/%d",
                    game.JobId, 
                    #Players:GetPlayers(), Players.MaxPlayers),
                inline = false
            }
        },
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        footer = {
            text = "Scanner Automático • " .. info.name
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
    
    -- Método 1: Server Hop externo
    local success, errorMsg = pcall(function()
        local module = loadstring(game:HttpGet("https://raw.githubusercontent.com/ScriptsHub07/steal/refs/heads/main/nada.lua"))()
        module:Teleport(game.PlaceId)
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
            print("⏰ Aguardando " .. SERVER_SWITCH_INTERVAL .. "s para trocar de servidor...")
            wait(SERVER_SWITCH_INTERVAL)
            
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
print("🚨 Sistema de alerta para brainrot > 150M ativado!")

coroutine.wrap(main)()


