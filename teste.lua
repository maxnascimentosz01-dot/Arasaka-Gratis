-- ARASAKA AUTO RACE | PC + MOBILE
-- Interface compacta preta e vermelha
local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    LobbyWait = 10.1,
    Primeiro = Vector3.new(-13369.75, 10.12, 0),
    Peso = Vector3.new(-13802.77, 8.10, 0),
    QuedaBraco = Vector3.new(-14539, 8, -4156),
    Chegada = Vector3.new(-14539, 8, -4158),
    PesoWait = 28,
    ClickDuration = 7,
    ClickInterval = 0.06,
    Descanso = 5,
}

local ativo = false
local ciclo = false
local connections = {}

-- LIMPAR VERSÃO ANTIGA
pcall(function()
    local old = CoreGui:FindFirstChild("ArasakaAutoRaceGui")
    if old then old:Destroy() end
end)

local function characterParts()
    local character = LocalPlayer.Character
        or LocalPlayer.CharacterAdded:Wait()
    return character,
        character:WaitForChild("HumanoidRootPart"),
        character:WaitForChild("Humanoid")
end

local function esperar(seconds)
    local deadline = os.clock() + seconds
    while ativo and os.clock() < deadline do
        task.wait(0.1)
    end
    return ativo
end

local function autoClick(seconds)
    local camera = workspace.CurrentCamera
    local viewport = camera.ViewportSize
    local x = viewport.X / 2
    local y = viewport.Y / 2

    local deadline = os.clock() + seconds
    while ativo and os.clock() < deadline do
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, true, game, 1)
        task.wait(0.03)
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
        task.wait(CONFIG.ClickInterval)
    end

    -- Garante que soltou o botão
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(x, y, 0, false, game, 1)
    end)

    return ativo
end

local function executarCorrida()
    local success, err = pcall(function()
        local _, root, humanoid = characterParts()
        local gym = workspace:WaitForChild("StrongbloxianGym")
        local raceWall = gym:WaitForChild("Lobby")
            :WaitForChild("Markers")
            :WaitForChild("RaceWall")

        if not ativo then return end

        -- 1. Lobby
        if raceWall:IsA("BasePart") then
            root.CFrame = raceWall.CFrame
        elseif raceWall:IsA("Model") then
            root.CFrame = raceWall:GetPivot()
        end

        -- 2. Espera da corrida
        if not esperar(CONFIG.LobbyWait) then return end
        local spawnZ = root.Position.Z

        -- 3. Primeiro teleporte
        root.CFrame = CFrame.new(
            CONFIG.Primeiro.X,
            CONFIG.Primeiro.Y,
            spawnZ
        )
        if not esperar(1) then return end

        -- 4. Local do peso
        local peso = Vector3.new(
            CONFIG.Peso.X,
            CONFIG.Peso.Y,
            spawnZ
        )
        root.CFrame = CFrame.new(peso)

        -- 5. Permanecer no peso
        local deadline = os.clock() + CONFIG.PesoWait
        while ativo and os.clock() < deadline do
            if not root.Parent then return end
            root.CFrame = CFrame.new(peso)
            task.wait(1)
        end
        if not ativo then return end

        -- 6. Dois pulos
        for _ = 1, 2 do
            if not ativo then return end
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            task.wait(0.3)
        end

        -- 7. Primeiro autoclick
        if not autoClick(CONFIG.ClickDuration) then return end

        -- 8. Queda de braço
        root.CFrame = CFrame.new(CONFIG.QuedaBraco)

        -- 9. Espera obrigatória
        if not esperar(3) then return end

        -- 10. Segundo autoclick
        if not autoClick(CONFIG.ClickDuration) then return end

        -- 11. Linha de chegada
        root.CFrame = CFrame.new(CONFIG.Chegada)
        if esperar(0.5) then
            print("[Arasaka] Ciclo concluído!")
        end
    end)

    if not success then
        warn("[Arasaka] Erro: " .. tostring(err))
    end
end

-- INTERFACE
local gui = Instance.new("ScreenGui")
gui.Name = "ArasakaAutoRaceGui"
gui.ResetOnSpawn = false

local parentOK = pcall(function()
    gui.Parent = CoreGui
end)
if not parentOK or not gui.Parent then
    gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
end

local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.fromOffset(165, 48)
frame.Position = UDim2.new(0, 35, 0, 80)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
frame.BorderSizePixel = 0
frame.Active = true
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(200, 0, 0)
stroke.Thickness = 2
stroke.Parent = frame

local button = Instance.new("TextButton")
button.Name = "ToggleBtn"
button.Size = UDim2.fromScale(1, 1)
button.BackgroundTransparency = 1
button.Text = "ARASAKA: OFF"
button.TextColor3 = Color3.new(1, 1, 1)
button.TextSize = 15
button.Font = Enum.Font.SourceSansBold
button.Active = true
button.Parent = frame

-- ARRASTAR: MOUSE E TOUCH
local dragging = false
local dragStart
local startPosition
local dragInput

frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = frame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

connections.drag = UserInputService.InputChanged:Connect(function(input)
    if dragging and input == dragInput then
        local delta = input.Position - dragStart
        frame.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

local function atualizarInterface()
    if ativo then
        frame.BackgroundColor3 = Color3.fromRGB(35, 10, 10)
        button.TextColor3 = Color3.fromRGB(255, 70, 70)
        button.Text = "ARASAKA: ON"
    else
        frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
        button.TextColor3 = Color3.new(1, 1, 1)
        button.Text = "ARASAKA: OFF"
    end
end

button.Activated:Connect(function()
    ativo = not ativo
    atualizarInterface()
    if ativo and not ciclo then
        ciclo = true
        task.spawn(function()
            while ativo do
                executarCorrida()
                if ativo then
                    esperar(CONFIG.Descanso)
                end
            end
            ciclo = false
        end)
    end
end)

print("[Arasaka] Auto Race carregado (Mobile Compatible).")
