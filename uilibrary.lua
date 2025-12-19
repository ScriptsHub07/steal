-- Futuristic Purple/Black UI Library v1.0
-- Pressione "K" para minimizar/maximizar

local UILibrary = {}

-- Configurações
local config = {
    PrimaryColor = Color3.fromRGB(138, 43, 226), -- Roxo
    SecondaryColor = Color3.fromRGB(20, 20, 20), -- Preto escuro
    AccentColor = Color3.fromRGB(98, 0, 234), -- Roxo mais vibrante
    TextColor = Color3.fromRGB(255, 255, 255),
    BorderColor = Color3.fromRGB(138, 43, 226),
    BackgroundTransparency = 0.1,
    BorderSize = 2,
    CornerRadius = UDim.new(0, 8),
    AnimationSpeed = 0.25
}

-- Serviços
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

-- Variáveis
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local mainFrame
local minimized = false
local minimizedPosition = UDim2.new(1, -50, 1, -50)
local originalPosition

-- Função para criar elementos comuns
function UILibrary.CreateElement(className, properties)
    local element = Instance.new(className)
    for prop, value in pairs(properties) do
        if prop == "Parent" then
            element.Parent = value
        else
            element[prop] = value
        end
    end
    return element
end

-- Função para criar gradiente
function UILibrary.CreateGradient(colors)
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, colors[1]),
        ColorSequenceKeypoint.new(1, colors[2])
    })
    return gradient
end

-- Função para criar efeito de brilho
function UILibrary.CreateGlow(parent)
    local glow = Instance.new("ImageLabel")
    glow.Name = "GlowEffect"
    glow.Image = "rbxassetid://8992231221"
    glow.ImageColor3 = config.PrimaryColor
    glow.BackgroundTransparency = 1
    glow.Size = UDim2.new(1, 40, 1, 40)
    glow.Position = UDim2.new(0, -20, 0, -20)
    glow.ZIndex = 0
    glow.ScaleType = Enum.ScaleType.Slice
    glow.SliceScale = 0.03
    glow.Parent = parent
    return glow
end

-- Função para criar menu principal
function UILibrary.CreateMenu(title, size, position)
    -- Tela principal
    local screenGui = UILibrary.CreateElement("ScreenGui", {
        Name = "FuturisticMenu",
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    })
    
    -- Frame principal com efeito de vidro
    mainFrame = UILibrary.CreateElement("Frame", {
        Name = "MainFrame",
        Size = size or UDim2.new(0, 400, 0, 500),
        Position = position or UDim2.new(0.5, -200, 0.5, -250),
        BackgroundColor3 = config.SecondaryColor,
        BackgroundTransparency = config.BackgroundTransparency,
        BorderSizePixel = 0,
        ZIndex = 2,
        Parent = screenGui
    })
    
    -- Efeito de vidro (blur)
    local glassEffect = UILibrary.CreateElement("Frame", {
        Name = "GlassEffect",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 0.95,
        BorderSizePixel = 0,
        ZIndex = 1
    })
    
    local uiCorner = UILibrary.CreateElement("UICorner", {
        CornerRadius = config.CornerRadius,
        Parent = glassEffect
    })
    glassEffect.Parent = mainFrame
    
    -- Borda brilhante
    local border = UILibrary.CreateElement("Frame", {
        Name = "Border",
        Size = UDim2.new(1, config.BorderSize * 2, 1, config.BorderSize * 2),
        Position = UDim2.new(0, -config.BorderSize, 0, -config.BorderSize),
        BackgroundColor3 = config.BorderColor,
        BorderSizePixel = 0,
        ZIndex = 1
    })
    
    local borderCorner = UILibrary.CreateElement("UICorner", {
        CornerRadius = config.CornerRadius,
        Parent = border
    })
    border.Parent = mainFrame
    
    -- Efeito de brilho na borda
    local borderGlow = UILibrary.CreateGlow(border)
    borderGlow.ImageColor3 = config.AccentColor
    borderGlow.ImageTransparency = 0.7
    
    -- Barra de título
    local titleBar = UILibrary.CreateElement("Frame", {
        Name = "TitleBar",
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Color3.fromRGB(10, 10, 10),
        BackgroundTransparency = 0.3,
        BorderSizePixel = 0,
        ZIndex = 3,
        Parent = mainFrame
    })
    
    local titleGradient = UILibrary.CreateGradient({
        Color3.fromRGB(20, 20, 20),
        Color3.fromRGB(30, 30, 30)
    })
    titleGradient.Parent = titleBar
    
    -- Título
    local titleLabel = UILibrary.CreateElement("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, -80, 1, 0),
        Position = UDim2.new(0, 10, 0, 0),
        BackgroundTransparency = 1,
        Text = title or "Futuristic Menu",
        TextColor3 = config.TextColor,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 4,
        Parent = titleBar
    })
    
    -- Botão minimizar
    local minimizeBtn = UILibrary.CreateElement("TextButton", {
        Name = "MinimizeButton",
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -70, 0.5, -15),
        BackgroundColor3 = config.PrimaryColor,
        BackgroundTransparency = 0.2,
        Text = "_",
        TextColor3 = config.TextColor,
        TextSize = 20,
        Font = Enum.Font.GothamBold,
        ZIndex = 4,
        Parent = titleBar
    })
    
    local minimizeCorner = UILibrary.CreateElement("UICorner", {
        CornerRadius = UDim.new(0, 4),
        Parent = minimizeBtn
    })
    
    -- Botão fechar
    local closeBtn = UILibrary.CreateElement("TextButton", {
        Name = "CloseButton",
        Size = UDim2.new(0, 30, 0, 30),
        Position = UDim2.new(1, -35, 0.5, -15),
        BackgroundColor3 = Color3.fromRGB(200, 50, 50),
        BackgroundTransparency = 0.2,
        Text = "X",
        TextColor3 = config.TextColor,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        ZIndex = 4,
        Parent = titleBar
    })
    
    local closeCorner = UILibrary.CreateElement("UICorner", {
        CornerRadius = UDim.new(0, 4),
        Parent = closeBtn
    })
    
    -- Container de conteúdo
    local contentContainer = UILibrary.CreateElement("Frame", {
        Name = "ContentContainer",
        Size = UDim2.new(1, -20, 1, -60),
        Position = UDim2.new(0, 10, 0, 50),
        BackgroundTransparency = 1,
        ZIndex = 2,
        Parent = mainFrame
    })
    
    local containerList = UILibrary.CreateElement("UIListLayout", {
        Padding = UDim.new(0, 10),
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = contentContainer
    })
    
    -- Arredondamento do frame principal
    local mainCorner = UILibrary.CreateElement("UICorner", {
        CornerRadius = config.CornerRadius,
        Parent = mainFrame
    })
    
    -- Funções de interação
    local dragging = false
    local dragInput, dragStart, startPos
    
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = mainFrame.Position
            
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    titleBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    UIS.InputChanged:Connect(function(input)
        if dragging and input == dragInput then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        end
    end)
    
    -- Função de minimizar
    local function toggleMinimize()
        minimized = not minimized
        
        local goal = {}
        if minimized then
            originalPosition = mainFrame.Position
            goal.Size = UDim2.new(0, 150, 0, 40)
            goal.Position = minimizedPosition
            contentContainer.Visible = false
        else
            goal.Size = size or UDim2.new(0, 400, 0, 500)
            goal.Position = originalPosition
            contentContainer.Visible = true
        end
        
        local tween = TweenService:Create(mainFrame, 
            TweenInfo.new(config.AnimationSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), 
            goal
        )
        tween:Play()
    end
    
    minimizeBtn.MouseButton1Click:Connect(toggleMinimize)
    
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    
    -- Tecla K para minimizar/maximizar
    UIS.InputBegan:Connect(function(input)
        if input.KeyCode == Enum.KeyCode.K then
            toggleMinimize()
        end
    end)
    
    -- Responsividade
    local function updateResponsiveness()
        local viewportSize = workspace.CurrentCamera.ViewportSize
        
        if minimized then
            minimizedPosition = UDim2.new(1, -50, 1, -50)
            if mainFrame then
                mainFrame.Position = minimizedPosition
            end
        end
    end
    
    screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(updateResponsiveness)
    updateResponsiveness()
    
    return screenGui, contentContainer, mainFrame
end

-- Função para criar botão
function UILibrary.CreateButton(parent, text, callback)
    local button = UILibrary.CreateElement("TextButton", {
        Name = "Button_" .. text,
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundColor3 = Color3.fromRGB(30, 30, 30),
        BackgroundTransparency = 0.2,
        Text = text,
        TextColor3 = config.TextColor,
        TextSize = 16,
        Font = Enum.Font.Gotham,
        LayoutOrder = #parent:GetChildren(),
        Parent = parent
    })
    
    local buttonCorner = UILibrary.CreateElement("UICorner", {
        CornerRadius = UDim.new(0, 6),
        Parent = button
    })
    
    -- Efeito de brilho no hover
    local buttonGlow = UILibrary.CreateGlow(button)
    buttonGlow.ImageTransparency = 1
    
    button.MouseEnter:Connect(function()
        buttonGlow.ImageTransparency = 0.5
        local tween = TweenService:Create(button, 
            TweenInfo.new(0.2), 
            {BackgroundColor3 = Color3.fromRGB(40, 40, 40)}
        )
        tween:Play()
    end)
    
    button.MouseLeave:Connect(function()
        buttonGlow.ImageTransparency = 1
        local tween = TweenService:Create(button, 
            TweenInfo.new(0.2), 
            {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}
        )
        tween:Play()
    end)
    
    button.MouseButton1Click:Connect(function()
        if callback then
            callback()
        end
        -- Efeito de clique
        local clickTween = TweenService:Create(button, 
            TweenInfo.new(0.1), 
            {BackgroundColor3 = config.PrimaryColor}
        )
        clickTween:Play()
        clickTween.Completed:Connect(function()
            local revertTween = TweenService:Create(button, 
                TweenInfo.new(0.2), 
                {BackgroundColor3 = Color3.fromRGB(30, 30, 30)}
            )
            revertTween:Play()
        end)
    end)
    
    return button
end

-- Função para criar toggle
function UILibrary.CreateToggle(parent, text, default, callback)
    local toggleFrame = UILibrary.CreateElement("Frame", {
        Name = "Toggle_" .. text,
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        LayoutOrder = #parent:GetChildren(),
        Parent = parent
    })
    
    local toggleLabel = UILibrary.CreateElement("TextLabel", {
        Name = "Label",
        Size = UDim2.new(0.7, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = config.TextColor,
        TextSize = 16,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = toggleFrame
    })
    
    local toggleButton = UILibrary.CreateElement("Frame", {
        Name = "ToggleButton",
        Size = UDim2.new(0, 50, 0, 24),
        Position = UDim2.new(1, -60, 0.5, -12),
        BackgroundColor3 = Color3.fromRGB(50, 50, 50),
        Parent = toggleFrame
    })
    
    local toggleCorner = UILibrary.CreateElement("UICorner", {
        CornerRadius = UDim.new(0, 12),
        Parent = toggleButton
    })
    
    local toggleCircle = UILibrary.CreateElement("Frame", {
        Name = "ToggleCircle",
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(0, 2, 0.5, -10),
        BackgroundColor3 = config.PrimaryColor,
        Parent = toggleButton
    })
    
    local circleCorner = UILibrary.CreateElement("UICorner", {
        CornerRadius = UDim.new(0, 10),
        Parent = toggleCircle
    })
    
    local state = default or false
    
    local function updateToggle()
        local goal = {}
        if state then
            goal.Position = UDim2.new(1, -22, 0.5, -10)
            goal.BackgroundColor3 = config.PrimaryColor
        else
            goal.Position = UDim2.new(0, 2, 0.5, -10)
            goal.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
        end
        
        local tween = TweenService:Create(toggleCircle, 
            TweenInfo.new(0.2), 
            goal
        )
        tween:Play()
        
        if callback then
            callback(state)
        end
    end
    
    toggleButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            state = not state
            updateToggle()
        end
    end)
    
    updateToggle()
    
    return toggleFrame
end

-- Função para criar slider
function UILibrary.CreateSlider(parent, text, min, max, default, callback)
    local sliderFrame = UILibrary.CreateElement("Frame", {
        Name = "Slider_" .. text,
        Size = UDim2.new(1, 0, 0, 60),
        BackgroundTransparency = 1,
        LayoutOrder = #parent:GetChildren(),
        Parent = parent
    })
    
    local sliderLabel = UILibrary.CreateElement("TextLabel", {
        Name = "Label",
        Size = UDim2.new(1, 0, 0, 20),
        BackgroundTransparency = 1,
        Text = text .. ": " .. (default or min),
        TextColor3 = config.TextColor,
        TextSize = 16,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = sliderFrame
    })
    
    local sliderTrack = UILibrary.CreateElement("Frame", {
        Name = "Track",
        Size = UDim2.new(1, 0, 0, 4),
        Position = UDim2.new(0, 0, 0, 30),
        BackgroundColor3 = Color3.fromRGB(50, 50, 50),
        Parent = sliderFrame
    })
    
    local trackCorner = UILibrary.CreateElement("UICorner", {
        CornerRadius = UDim.new(0, 2),
        Parent = sliderTrack
    })
    
    local sliderFill = UILibrary.CreateElement("Frame", {
        Name = "Fill",
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = config.PrimaryColor,
        Parent = sliderTrack
    })
    
    local fillCorner = UILibrary.CreateElement("UICorner", {
        CornerRadius = UDim.new(0, 2),
        Parent = sliderFill
    })
    
    local sliderButton = UILibrary.CreateElement("TextButton", {
        Name = "SliderButton",
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(0, -10, 0.5, -10),
        BackgroundColor3 = config.TextColor,
        Text = "",
        Parent = sliderTrack
    })
    
    local buttonCorner = UILibrary.CreateElement("UICorner", {
        CornerRadius = UDim.new(0, 10),
        Parent = sliderButton
    })
    
    local value = default or min
    local sliding = false
    
    local function updateSlider(newValue)
        value = math.clamp(newValue, min, max)
        local percentage = (value - min) / (max - min)
        
        sliderFill.Size = UDim2.new(percentage, 0, 1, 0)
        sliderButton.Position = UDim2.new(percentage, -10, 0.5, -10)
        sliderLabel.Text = text .. ": " .. math.floor(value)
        
        if callback then
            callback(value)
        end
    end
    
    sliderButton.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = true
        end
    end)
    
    sliderButton.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            sliding = false
        end
    end)
    
    UIS.InputChanged:Connect(function(input)
        if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
            local mousePos = mouse.X
            local trackPos = sliderTrack.AbsolutePosition.X
            local trackSize = sliderTrack.AbsoluteSize.X
            
            local relativePos = math.clamp(mousePos - trackPos, 0, trackSize)
            local percentage = relativePos / trackSize
            local newValue = min + (max - min) * percentage
            
            updateSlider(newValue)
        end
    end)
    
    updateSlider(value)
    
    return sliderFrame
end

-- Função para criar label
function UILibrary.CreateLabel(parent, text)
    local label = UILibrary.CreateElement("TextLabel", {
        Name = "Label_" .. text,
        Size = UDim2.new(1, 0, 0, 25),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = config.TextColor,
        TextSize = 16,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = #parent:GetChildren(),
        Parent = parent
    })
    
    return label
end

-- Função para criar seção
function UILibrary.CreateSection(parent, title)
    local sectionFrame = UILibrary.CreateElement("Frame", {
        Name = "Section_" .. title,
        Size = UDim2.new(1, 0, 0, 40),
        BackgroundTransparency = 1,
        LayoutOrder = #parent:GetChildren(),
        Parent = parent
    })
    
    local sectionTitle = UILibrary.CreateElement("TextLabel", {
        Name = "Title",
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = config.PrimaryColor,
        TextSize = 18,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = sectionFrame
    })
    
    local underline = UILibrary.CreateElement("Frame", {
        Name = "Underline",
        Size = UDim2.new(1, 0, 0, 2),
        Position = UDim2.new(0, 0, 1, -2),
        BackgroundColor3 = config.PrimaryColor,
        Parent = sectionFrame
    })
    
    return sectionFrame
end

-- Exemplo de uso
function UILibrary:Example()
    local screenGui, content = UILibrary.CreateMenu("Futuristic Menu", UDim2.new(0, 400, 0, 500))
    screenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    -- Adicionar elementos de exemplo
    UILibrary.CreateSection(content, "Controles")
    
    UILibrary.CreateButton(content, "Executar Script", function()
        print("Script executado!")
    end)
    
    UILibrary.CreateToggle(content, "Ativar God Mode", false, function(state)
        print("God Mode:", state)
    end)
    
    UILibrary.CreateSlider(content, "Velocidade", 0, 100, 50, function(value)
        print("Velocidade:", value)
    end)
    
    UILibrary.CreateLabel(content, "Bem-vindo ao menu futurista!")
    
    UILibrary.CreateButton(content, "Sair", function()
        screenGui:Destroy()
    end)
end

return UILibrary
