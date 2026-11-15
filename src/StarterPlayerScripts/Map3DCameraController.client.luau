local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local map = workspace:WaitForChild("MapBlockoutV2")
local folder = map:WaitForChild("CameraPoints")
local points = {}
repeat
	points = {}
	for _, item in ipairs(folder:GetChildren()) do
		if item:IsA("BasePart") then
			table.insert(points, item)
		end
	end
	if #points == 0 then
		task.wait()
	end
until #points > 0
table.sort(points, function(a, b)
	return a.Name < b.Name
end)
local active = false
local index = 1
local pg = player:WaitForChild("PlayerGui")
local old = pg:FindFirstChild("SecurityCameraHUD")
if old then
	old:Destroy()
end
local gui = Instance.new("ScreenGui")
gui.Name = "SecurityCameraHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.Parent = pg
local function round(o, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = o
end
local function stroke(o, col)
	local s = Instance.new("UIStroke")
	s.Color = col
	s.Thickness = 2
	s.Parent = o
end
local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 1, -22)
label.Size = UDim2.fromOffset(560, 54)
label.BackgroundColor3 = Color3.fromRGB(8, 13, 20)
label.BackgroundTransparency = 0.08
label.TextColor3 = Color3.fromRGB(120, 240, 255)
label.Font = Enum.Font.GothamBold
label.TextScaled = true
label.Text = "[C] CÁMARAS  |  Q/E: PUERTAS"
label.Parent = gui
round(label, 10)
stroke(label, Color3.fromRGB(40, 150, 180))
local function makeDoor(name, text, pos, anchor)
	local b = Instance.new("TextButton")
	b.Name = name
	b.AnchorPoint = anchor
	b.Position = pos
	b.Size = UDim2.fromOffset(245, 72)
	b.BackgroundColor3 = Color3.fromRGB(24, 65, 48)
	b.TextColor3 = Color3.fromRGB(150, 255, 190)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 20
	b.TextWrapped = true
	b.Text = text
	b.Parent = gui
	round(b, 10)
	stroke(b, Color3.fromRGB(60, 210, 125))
	return b
end
local left = makeDoor("DoorLeftPersistent", "[Q] PUERTA IZQUIERDA\nABIERTA", UDim2.new(0, 24, 1, -100), Vector2.new(0, 1))
local right = makeDoor("DoorRightPersistent", "[E] PUERTA DERECHA\nABIERTA", UDim2.new(1, -24, 1, -100), Vector2.new(1, 1))
local function originalButton(name)
	return pg:FindFirstChild(name, true)
end
local NetworkProtocol = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("NetworkProtocol"))
local requestAction = NetworkProtocol.obtenerRemotos().RequestPlayerAction
local function trigger(lado, name)
	local b = originalButton(name)
	if not b or not b:IsA("TextButton") then
		return
	end
	local upper = string.upper(b.Text)
	if string.find(upper, "SIN ENERG", 1, true) then
		return
	end
	local closed = string.find(upper, "CERRADA", 1, true) ~= nil
	requestAction:FireServer({ tipo = "ALTERNAR_PUERTA", lado = lado, cerrada = not closed, lineaId = "L0" })
end
left.MouseButton1Click:Connect(function()
	trigger("Izquierda", "BtnPuertaIzquierda")
end)
right.MouseButton1Click:Connect(function()
	trigger("Derecha", "BtnPuertaDerecha")
end)
local function mirror(target, name, key, title)
	local src = originalButton(name)
	if src and src:IsA("TextButton") then
		local closed = string.find(string.upper(src.Text), "CERRADA", 1, true) ~= nil
		local noPower = string.find(string.upper(src.Text), "SIN ENERG", 1, true) ~= nil
		if noPower then
			target.Text = "[" .. key .. "] " .. title .. "\nSIN ENERGÍA"
			target.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
			target.TextColor3 = Color3.fromRGB(190, 190, 190)
		elseif closed then
			target.Text = "[" .. key .. "] " .. title .. "\nCERRADA"
			target.BackgroundColor3 = Color3.fromRGB(105, 25, 32)
			target.TextColor3 = Color3.fromRGB(255, 145, 145)
		else
			target.Text = "[" .. key .. "] " .. title .. "\nABIERTA"
			target.BackgroundColor3 = Color3.fromRGB(24, 65, 48)
			target.TextColor3 = Color3.fromRGB(150, 255, 190)
		end
	end
end
local function show()
	if not active then
		camera.CameraType = Enum.CameraType.Custom
		label.Text = "[C] CÁMARAS  |  Q/E: PUERTAS"
		return
	end
	local p = points[index]
	if not p then
		active = false
		camera.CameraType = Enum.CameraType.Custom
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.CFrame = p.CFrame
	label.Text = p.Name .. "  |  ←/→: CAMBIAR  |  C: SALIR  |  Q/E: PUERTAS"
end
UIS.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.C then
		active = not active
		show()
	elseif active and input.KeyCode == Enum.KeyCode.Right then
		index = index % #points + 1
		show()
	elseif active and input.KeyCode == Enum.KeyCode.Left then
		index = (index - 2) % #points + 1
		show()
	end
end)
RunService.RenderStepped:Connect(function()
	mirror(left, "BtnPuertaIzquierda", "Q", "PUERTA IZQUIERDA")
	mirror(right, "BtnPuertaDerecha", "E", "PUERTA DERECHA")
end)
