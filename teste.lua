

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    LobbyWait = 10.1,
    PrimeiroX = -13369.75,
    PrimeiroY = 10.12,
    PesoX = -13802.77,
    PesoY = 8.10,
    QuedaBraco = Vector3.new(-14539, 8, -4156),
    Chegada = Vector3.new(-14539, 8, -4158),
    PesoWait = 28,
    ClickDuration = 7,
    ClickInterval = 0.08,
    Descanso = 5,
}

local ativo = false
local ciclo = false

-- Limpeza da interface anterior
pcall(function()
    local old = CoreGui:FindFirstChild("ArasakaAutoRaceGui")
    if old then
        old:Destroy()
    end
end)

local function characterParts()
    local character = LocalPlayer.Character
        or LocalPlayer.CharacterAdded:Wait()

    local root = character:WaitForChild("HumanoidRootPart")
    local humanoid = character:WaitForChild("Humanoid")

    return character, root, humanoid
end

local function getRaceWall()
    local gym = workspace:WaitForChild("StrongbloxianGym")
    local lobby = gym:WaitForChild("Lobby")
    local markers = lobby:WaitForChild("Markers")

    return markers:WaitForChild("RaceWall")
end

-- Autoclick de entrada virtual quando disponível.
-- O jogo precisa aceitar essa entrada para registrar a ação.
local function autoClick(seconds)
    local deadline = os.clock() + seconds
    local virtualInput

    local ok, result = pcall(function()
        return UserInputService:CreateVirtualInput()
    end)

    if ok then
        virtualInput = result
    end

    if not virtualInput then
        warn("[Arasaka] Entrada virtual indisponível neste executor.")
        return false
    end

    local mousePosition = Vector2.new(500, 500)

    while ativo and os.clock() < deadline do
        local pressed = pcall(function()
            virtualInput:SendMouseButton(
                mousePosition,
                Enum.UserInputType.MouseButton1,
                true,
                0
            )
        end)

        if pressed then
            task.wait(0.035)

            pcall(function()
                virtualInput:SendMouseButton(
                    mousePosition,
                    Enum.UserInputType.MouseButton1,
                    false,
                    0
                )
            end)
        else
            warn("[Arasaka] O executor recusou a entrada virtual.")
            return false
        end

        task.wait(CONFIG.ClickInterval)
    end

    return ativo
end

local function esperar(seconds)
    local deadline = os.clock() + seconds

    while ativo and os.clock() < deadline do
        task.wait(0.1)
    end

    return ativo
end

local function teleport(root, position)
    if not ativo or not root or not root.Parent then
        return false
    end

    root.CFrame = CFrame.new(position)
    return true
end

local function executarCorrida()
    local success, err = pcall(function()
        local _, root, humanoid = characterParts()
        local raceWall = getRaceWall()

        if not ativo then return end

        -- 1. Entrada no lobby
        if raceWall:IsA("BasePart") then
            root.CFrame = raceWall.CFrame
        elseif raceWall:IsA("Model") then
            root.CFrame = raceWall:GetPivot()
        else
            warn("[Arasaka] RaceWall não é uma peça ou modelo.")
            return
        end

        -- 2. Espera inicial
        if not esperar(CONFIG.LobbyWait) then return end

        local spawnZ = root.Position.Z

        -- 3. Primeiro ponto
        teleport(root, Vector3.new(
            CONFIG.PrimeiroX,
            CONFIG.PrimeiroY,
            spawnZ
        ))

        if not esperar(1) then return end

        -- 4. Ponto do peso
        local peso = Vector3.new(
            CONFIG.PesoX,
            CONFIG.PesoY,
            spawnZ
        )

        teleport(root, peso)

        -- 5. Mantém posição durante o desafio
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

            pcall(function()
                humanoid:ChangeState(
                    Enum.HumanoidStateType.Jumping
                )
            end)

            task.wait(0.3)
        end

        -- 7. Primeiro autoclick
        if not autoClick(CONFIG.ClickDuration) then
            warn("[Arasaka] Primeiro autoclick não foi concluído.")
            return
        end

        -- 8. Queda de braço
        teleport(root, CONFIG.QuedaBraco)

        -- 9. Espera obrigatória
        if not esperar(3) then return end

        -- 10. Segundo autoclick
        if not autoClick(CONFIG.ClickDuration) then
            warn("[Arasaka] Segundo autoclick não foi concluído.")
            return
        end

        -- 11. Chegada
        teleport(root, CONFIG.Chegada)

        esperar(0.5)

        if ativo then
            print("[Arasaka] Ciclo concluído.")
        end
    end)

    if not success then
        warn("[Arasaka] Erro no ciclo: " .. tostring(err))
    end
end

-- Interface
local gui = Instance.new("ScreenGui")
gui.Name = "ArasakaAutoRaceGui"
gui.ResetOnSpawn = false

pcall(function()
    gui.Parent = CoreGui
end)

if not gui.Parent then
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

-- Arrastar com mouse ou toque
local dragging = false
local dragStart
local startPosition
local activeInput

frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then

        dragging = true
        dragStart = input.Position
        startPosition = frame.Position
        activeInput = input

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                activeInput = nil
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if not dragging then return end

    local isMouseMove =
        input.UserInputType == Enum.UserInputType.MouseMovement

    local isTouchMove =
        input.UserInputType == Enum.UserInputType.Touch
        and activeInput == input

    if isMouseMove or isTouchMove then
        local delta = input.Position - dragStart

        frame.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end)

local function atualizarBotao()
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
    atualizarBotao()

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

print("[Arasaka] Auto Race carregado.")
