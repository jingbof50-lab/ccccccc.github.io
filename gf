-- 保留原脚本所有依赖服务与初始化逻辑（不变）
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
if not game:IsLoaded() then
	game.Loaded:Wait()
end
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	LocalPlayer = Players.LocalPlayer
end
-- 原作者信息提示（更新功能说明）
local authorMessage = Instance.new("Message")
authorMessage.Text = "多物体漂浮控制腳本 - 作者: XTTT\n1: 可選中多個物體，點擊已選物體取消選擇\n2: 新增「物體移至玩家」「物體圍繞玩家」「一鍵全選」按鈕\n3: 「一鍵全選」掃描所有文件夾、嵌套模型內的可控制物體\n4: 按了停止翻轉後再按任意移動鍵才能真正停止翻轉\n5: 只能控制未被固定的物體！\n6: 只有能被藍色框架標記的才是「可能」能控制的物體，物體太大可能無法控制\n7: 選好物體後可關閉選擇模式\n8: 此腳本為免費腳本，禁止販賣\n更新了控制面板UI大小調整功能，調整按鈕在最下方\n感謝使用"
authorMessage.Parent = Workspace
delay(5, function()
	authorMessage:Destroy()
end)
-- 原全局变量（不变）
_G.selectedParts = {} 
_G.highlights = {} 
_G.floatSpeed = 10
_G.moveDirection = Vector3.new(0, 1, 0)
_G.flipX = 0
_G.flipY = 0
_G.flipZ = 0
_G.rotationSpeed = 1
_G.isOrbiting = false 
_G.orbitConnection = nil 
_G.orbitConfig = {
	radius = 12,     
	speed = 0.6,     
	heightOffset = 2 
}
-- 原角色重生与模拟半径逻辑（不变）
local function setupAutoReconnect()
	LocalPlayer.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		setupSimulationRadius()
		if _G.isOrbiting then
			stopOrbit()
		end
		print("角色已重生，漂浮控制腳本已自動重新連接")
	end)
	LocalPlayer.CharacterRemoving:Connect(function()
		if #_G.selectedParts > 0 then
			pcall(function()
				StopPart() 
				removeAllHighlights() 
			end)
			_G.selectedParts = {}
		end
		if _G.isOrbiting then
			stopOrbit()
		end
	end)
end
local function setupSimulationRadius()
	local success, err = pcall(function()
		RunService.Heartbeat:Connect(function()
			pcall(function()
				sethiddenproperty(LocalPlayer, "SimulationRadius", math.huge)
				sethiddenproperty(LocalPlayer, "MaxSimulationRadius", math.huge)
			end)
		end)
	end)
	if not success then
		warn("模擬半徑設定失敗: " .. tostring(err))
	end
end
setupSimulationRadius()
setupAutoReconnect()
-- 原高亮、停止、处理物体等核心函数（不变）
local function createHighlight(part)
	local highlight = Instance.new("SelectionBox")
	highlight.Name = "FloatingHighlight"
	highlight.Adornee = part
	highlight.Color3 = Color3.fromRGB(0, 0, 255)
	highlight.LineThickness = 0.05
	highlight.Parent = part
	return highlight
end
local function removeAllHighlights()
	for _, highlight in pairs(_G.highlights) do
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end
	_G.highlights = {}
end
local function ProcessPart(targetPart)
	local partsToProcess = targetPart and {targetPart} or _G.selectedParts
	for _, part in ipairs(partsToProcess) do
		if not part or not part.Parent then continue end
		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("BodyVelocity") or child:IsA("BodyAngularVelocity") or 
			   child:IsA("BodyForce") or child:IsA("BodyGyro") or 
			   child:IsA("BodyPosition") or child:IsA("BodyThrust") then
				child:Destroy()
			end
		end
		local bodyVelocity = Instance.new("BodyVelocity")
		bodyVelocity.Velocity = _G.moveDirection.Unit * _G.floatSpeed
		bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
		bodyVelocity.Parent = part
		local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
		bodyAngularVelocity.AngularVelocity = Vector3.new(_G.flipX, _G.flipY, _G.flipZ) * _G.rotationSpeed
		bodyAngularVelocity.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
		bodyAngularVelocity.Parent = part
	end
end
local function StopPart(targetPart)
	local partsToStop = targetPart and {targetPart} or _G.selectedParts
	for _, part in ipairs(partsToStop) do
		if part and part.Parent then
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("BodyVelocity") or child:IsA("BodyAngularVelocity") then
					child:Destroy()
				end
			end
		end
	end
end
local function StopFlip(targetPart)
	local partsToStop = targetPart and {targetPart} or _G.selectedParts
	for _, part in ipairs(partsToStop) do
		if part and part.Parent then
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("BodyAngularVelocity") then
					child:Destroy()
				end
			end
		end
	end
	_G.flipX = 0
	_G.flipY = 0
	_G.flipZ = 0
end
local function UpdatePartMovement()
	if #_G.selectedParts == 0 then return end
	StopPart()
	ProcessPart()
end
local function IsPartControllable(part)
	return part:IsA("Part") and not part.Anchored and not part.Parent:FindFirstChild("Humanoid") and 
		not part.Parent:FindFirstChild("Head") and part.Parent ~= LocalPlayer.Character
end
local function SelectPart(part)
	if not IsPartControllable(part) then return false end
	local isSelected = false
	local removeIndex = nil
	for i, selectedPart in ipairs(_G.selectedParts) do
		if selectedPart == part then
			isSelected = true
			removeIndex = i
			break
		end
	end
	if isSelected then
		table.remove(_G.selectedParts, removeIndex)
		if _G.highlights[part] then
			_G.highlights[part]:Destroy()
			_G.highlights[part] = nil
		end
		StopPart(part)
	else
		table.insert(_G.selectedParts, part)
		local highlight = createHighlight(part)
		_G.highlights[part] = highlight
		ProcessPart(part)
	end
	return true
end
local function DeselectAllParts()
	if #_G.selectedParts == 0 then return end
	removeAllHighlights()
	StopPart()
	_G.selectedParts = {}
	print("已取消所有物體選擇")
end
local function MoveToPlayer()
	local character = LocalPlayer.Character
	if not character then
		warn("角色未加載，無法移動物體")
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		warn("未找到角色核心部件，無法移動物體")
		return
	end
	if #_G.selectedParts == 0 then
		warn("未選中任何物體，無法執行移動")
		return
	end
	local targetPos = rootPart.Position + rootPart.CFrame.LookVector * 10
	for _, part in ipairs(_G.selectedParts) do
		if not part or not part.Parent then continue end
		_G.moveDirection = (targetPos - part.Position).Unit
		ProcessPart(part)
	end
	print("已指令所有選中物體移向玩家")
end
local function getTargetPart()
	local camera = Workspace.CurrentCamera
	local mousePos = UserInputService:GetMouseLocation()
	local unitRay = camera:ViewportPointToRay(mousePos.X, mousePos.Y)
	local ray = Ray.new(unitRay.Origin, unitRay.Direction * 1000)
	local part, position = Workspace:FindPartOnRay(ray, LocalPlayer.Character)
	return part
end
local function getCameraRelativeDirection(direction)
	local camera = Workspace.CurrentCamera
	if not camera then return direction end
	local cameraCFrame = camera.CFrame
	local relativeDirection = Vector3.new(0, 0, 0)
	if direction == Vector3.new(0, 0, 1) then
		relativeDirection = Vector3.new(cameraCFrame.LookVector.X, 0, cameraCFrame.LookVector.Z).Unit
	elseif direction == Vector3.new(0, 0, -1) then
		relativeDirection = Vector3.new(-cameraCFrame.LookVector.X, 0, -cameraCFrame.LookVector.Z).Unit
	elseif direction == Vector3.new(-1, 0, 0) then
		relativeDirection = Vector3.new(-cameraCFrame.RightVector.X, 0, -cameraCFrame.RightVector.Z).Unit
	elseif direction == Vector3.new(1, 0, 0) then
		relativeDirection = Vector3.new(cameraCFrame.RightVector.X, 0, cameraCFrame.RightVector.Z).Unit
	else
		relativeDirection = direction
	end
	return relativeDirection
end
local function MakeDraggable(gui)
	gui.Active = true
	gui.Draggable = true
	local dragHandle = Instance.new("Frame")
	dragHandle.Name = "DragHandle"
	dragHandle.Size = UDim2.new(0, 20, 0, 20)
	dragHandle.Position = UDim2.new(1, -20, 0, 0)
	dragHandle.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
	dragHandle.BorderSizePixel = 0
	dragHandle.Parent = gui
	local gripIcon = Instance.new("TextLabel")
	gripIcon.Name = "GripIcon"
	gripIcon.Size = UDim2.new(1, 0, 1, 0)
	gripIcon.Position = UDim2.new(0, 0, 0, 0)
	gripIcon.Text = "≡"
	gripIcon.TextColor3 = Color3.new(1, 1, 1)
	gripIcon.BackgroundTransparency = 1
	gripIcon.TextSize = 14
	gripIcon.Parent = dragHandle
	dragHandle.Active = true
	dragHandle.Draggable = true
end
-- 【关键优化】一键全选函数：扫描所有文件夹、所有嵌套模型内的可控制物体
local function SelectAllParts()
	-- 1. 先清空现有选择，避免重复选中
	DeselectAllParts()
	-- 2. 统计选中数量（用于最终提示）
	local selectedCount = 0
	-- 3. 深度递归函数：遍历所有实例（包括Folder、Model、嵌套Model）
	local function deepScanInstances(parentInstance)
		-- 遍历当前实例的所有子对象
		for _, child in ipairs(parentInstance:GetChildren()) do
			-- 情况1：子对象是Folder（文件夹）→ 继续递归扫描文件夹内内容
			if child:IsA("Folder") then
				deepScanInstances(child)
			-- 情况2：子对象是Model（模型）→ 继续递归扫描模型内嵌套的实例
			elseif child:IsA("Model") then
				deepScanInstances(child)
			-- 情况3：子对象是Part（方块）→ 检查是否可控制，可控制则选中
			elseif child:IsA("Part") then
				if IsPartControllable(child) then
					SelectPart(child)
					selectedCount = selectedCount + 1
				end
			-- 忽略其他类型实例（如Script、Sound、Attachment等）
			end
		end
	end
	-- 4. 从Workspace根节点开始扫描，覆盖所有文件夹、模型
	deepScanInstances(Workspace)
	-- 5. 输出结果提示
	if selectedCount == 0 then
		print("一键全选完成：未找到任何可控制物体（仅未固定、非角色部件的方块可选中）")
	else
		print(string.format("一键全选完成：共选中 %d 个可控制物体（覆盖所有文件夹、嵌套模型）", selectedCount))
	end
end
-- 物体围绕玩家逻辑（不变）
local function startOrbit()
	local character = LocalPlayer.Character
	if not character then
		warn("角色未加载，无法启动围绕")
		return
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		warn("未找到角色核心部件，无法启动围绕")
		return
	end
	if #_G.selectedParts == 0 then
		warn("未选中任何物体，无法启动围绕")
		return
	end
	if _G.isOrbiting then return end
	_G.isOrbiting = true
	_G.orbitConnection = RunService.Heartbeat:Connect(function()
		if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
			stopOrbit()
			return
		end
		rootPart = LocalPlayer.Character.HumanoidRootPart
		local currentTime = tick()
		for _, part in ipairs(_G.selectedParts) do
			if not part or not part.Parent then continue end
			local orbitAngle = currentTime * _G.orbitConfig.speed
			local targetX = rootPart.Position.X + _G.orbitConfig.radius * math.cos(orbitAngle)
			local targetZ = rootPart.Position.Z + _G.orbitConfig.radius * math.sin(orbitAngle)
			local targetPos = Vector3.new(targetX, rootPart.Position.Y + _G.orbitConfig.heightOffset, targetZ)
			
			_G.moveDirection = (targetPos - part.Position).Unit
			ProcessPart(part)
		end
	end)
	print("已启动物体围绕玩家移动")
end
local function stopOrbit()
	if _G.orbitConnection then
		_G.orbitConnection:Disconnect()
		_G.orbitConnection = nil
	end
	_G.isOrbiting = false
	print("已停止物体围绕玩家移动")
end
local function toggleOrbit()
	if _G.isOrbiting then
		stopOrbit()
	else
		startOrbit()
	end
end
-- 【核心修改】GUI创建函数（按需求调整尺寸、滑动、标题、布局）
local function CreateMobileGUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "MultiObjectFloatingControl"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
	local btnHeight = 40  -- 统一按钮高度，优化整齐度
	local btnSpacing = 8  -- 统一间距，减少冗余
	-- 选择模式按钮（位置微调，保持一致性）
	local selectModeButton = Instance.new("TextButton")
	selectModeButton.Name = "SelectModeToggle"
	selectModeButton.Size = UDim2.new(0, 150, 0, btnHeight)
	selectModeButton.Position = UDim2.new(1, -160, 0, btnSpacing)
	selectModeButton.Text = "選擇模式: 關閉"
	selectModeButton.TextSize = 16
	selectModeButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
	selectModeButton.TextColor3 = Color3.new(1, 1, 1)
	selectModeButton.Parent = screenGui
	MakeDraggable(selectModeButton)
	-- 打开面板按钮（位置微调）
	local openPanelButton = Instance.new("TextButton")
	openPanelButton.Name = "OpenPanel"
	openPanelButton.Size = UDim2.new(0, 150, 0, btnHeight)
	openPanelButton.Position = UDim2.new(1, -160, 0, btnHeight + btnSpacing * 2)
	openPanelButton.Text = "打開控制面板"
	openPanelButton.TextSize = 16
	openPanelButton.BackgroundColor3 = Color3.fromRGB(100, 100, 200)
	openPanelButton.TextColor3 = Color3.new(1, 1, 1)
	openPanelButton.Visible = true
	openPanelButton.Parent = screenGui
	MakeDraggable(openPanelButton)
	-- 1. 控制面板：尺寸改为300x200，居中显示
	local controlPanel = Instance.new("Frame")
	controlPanel.Name = "ControlPanel"
	controlPanel.Size = UDim2.new(0, 300, 0, 200)  -- 核心尺寸修改
	controlPanel.Position = UDim2.new(0.5, -150, 0.5, -100)  -- 居中对齐
	controlPanel.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
	controlPanel.BackgroundTransparency = 0.3
	controlPanel.BorderSizePixel = 0
	controlPanel.Visible = false
	controlPanel.Parent = screenGui
	MakeDraggable(controlPanel)
	-- 2. 标题：添加"宇宙-控制物品"，固定在面板顶部（不随滚动移动）
	local panelTitle = Instance.new("TextLabel")
	panelTitle.Name = "PanelTitle"
	panelTitle.Size = UDim2.new(1, 0, 0, 30)
	panelTitle.Position = UDim2.new(0, 0, 0, 0)
	panelTitle.Text = "宇宙-控制物品"
	panelTitle.TextColor3 = Color3.new(1, 1, 1)
	panelTitle.BackgroundTransparency = 1
	panelTitle.TextSize = 18
	panelTitle.Font = Enum.Font.SourceSansBold  -- 标题加粗，更醒目
	panelTitle.Parent = controlPanel
	-- 3. 滚动容器：实现可滑动功能，承载所有控制元素
	local scrollFrame = Instance.new("ScrollingFrame")
	scrollFrame.Name = "ControlScrollFrame"
	scrollFrame.Size = UDim2.new(1, 0, 1, -30)  -- 高度减去标题高度
	scrollFrame.Position = UDim2.new(0, 0, 0, 30)  -- 位于标题下方
	scrollFrame.BackgroundTransparency = 1
	scrollFrame.ScrollBarThickness = 6  -- 滚动条粗细，优化手感
	scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(150, 150, 150)
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 700)  -- 画布高度适配所有元素
	scrollFrame.Parent = controlPanel
	-- 滚动容器内的内容框架（统一承载所有控件，保证对齐）
	local scrollContent = Instance.new("Frame")
	scrollContent.Name = "ScrollContent"
	scrollContent.Size = UDim2.new(1, 0, 0, 700)  -- 与画布高度一致
	scrollContent.BackgroundTransparency = 1
	scrollContent.Parent = scrollFrame
	-- UI缩放（放在滚动内容内，位置统一）
	local uiScale = Instance.new("UIScale")
	uiScale.Scale = 1.0
	uiScale.Parent = scrollContent
	-- 统一创建分区标签函数（调整y轴基准为scrollContent）
	local function createSectionLabel(text, yPos)
		local label = Instance.new("TextLabel")
		label.Name = text .. "Label"
		label.Size = UDim2.new(1, 0, 0, 30)
		label.Position = UDim2.new(0, 0, 0, yPos)
		label.Text = text
		label.TextColor3 = Color3.new(1, 1, 1)
		label.BackgroundTransparency = 1
		label.TextSize = 16
		label.Font = Enum.Font.SourceSansSemibold
		label.Parent = scrollContent
		return label
	end
	-- 1. UI缩放区（y=10，统一起始位置）
	local scaleLabel = createSectionLabel("UI大小: 1.0", 10)
	local scaleBtnSize = UDim2.new(0, 50, 0, 35)  -- 缩小按钮尺寸，适配小面板
	local scaleUpButton = Instance.new("TextButton")
	scaleUpButton.Name = "ScaleUp"
	scaleUpButton.Size = scaleBtnSize
	scaleUpButton.Position = UDim2.new(0.65, -25, 0, 40)  -- 右对齐
	scaleUpButton.Text = "+"
	scaleUpButton.TextSize = 24
	scaleUpButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
	scaleUpButton.TextColor3 = Color3.new(1, 1, 1)
	scaleUpButton.Parent = scrollContent
	local scaleDownButton = Instance.new("TextButton")
	scaleDownButton.Name = "ScaleDown"
	scaleDownButton.Size = scaleBtnSize
	scaleDownButton.Position = UDim2.new(0.35, -25, 0, 40)  -- 左对齐
	scaleDownButton.Text = "-"
	scaleDownButton.TextSize = 24
	scaleDownButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
	scaleDownButton.TextColor3 = Color3.new(1, 1, 1)
	scaleDownButton.Parent = scrollContent
	-- 2. 速度控制区（y=90，与上一区间距25）
	local speedLabel = createSectionLabel("速度: " .. _G.floatSpeed, 90)
	local speedUpButton = Instance.new("TextButton")
	speedUpButton.Name = "SpeedUp"
	speedUpButton.Size = scaleBtnSize
	speedUpButton.Position = UDim2.new(0.65, -25, 0, 120)
	speedUpButton.Text = "+"
	speedUpButton.TextSize = 24
	speedUpButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
	speedUpButton.TextColor3 = Color3.new(1, 1, 1)
	speedUpButton.Parent = scrollContent
	local speedDownButton = Instance.new("TextButton")
	speedDownButton.Name = "SpeedDown"
	speedDownButton.Size = scaleBtnSize
	speedDownButton.Position = UDim2.new(0.35, -25, 0, 120)
	speedDownButton.Text = "-"
	speedDownButton.TextSize = 24
	speedDownButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
	speedDownButton.TextColor3 = Color3.new(1, 1, 1)
	speedDownButton.Parent = scrollContent
	-- 3. 核心控制按钮区（统一居中，y=170起，间距8）
	local ctrlBtnSize = UDim2.new(0, 180, 0, 35)  -- 加宽按钮，文字更清晰
	local stopButton = Instance.new("TextButton")
	stopButton.Name = "Stop"
	stopButton.Size = ctrlBtnSize
	stopButton.Position = UDim2.new(0.5, -90, 0, 170)
	stopButton.Text = "停止移動"
	stopButton.TextSize = 14
	stopButton.BackgroundColor3 = Color3.fromRGB(200, 100, 100)
	stopButton.TextColor3 = Color3.new(1, 1, 1)
	stopButton.Parent = scrollContent
	local stopFlipButton = Instance.new("TextButton")
	stopFlipButton.Name = "StopFlip"
	stopFlipButton.Size = ctrlBtnSize
	stopFlipButton.Position = UDim2.new(0.5, -90, 0, 170 + btnHeight + btnSpacing)
	stopFlipButton.Text = "停止翻轉"
	stopFlipButton.TextSize = 14
	stopFlipButton.BackgroundColor3 = Color3.fromRGB(200, 100, 100)
	stopFlipButton.TextColor3 = Color3.new(1, 1, 1)
	stopFlipButton.Parent = scrollContent
	local deselectAllButton = Instance.new("TextButton")
	deselectAllButton.Name = "DeselectAll"
	deselectAllButton.Size = ctrlBtnSize
	deselectAllButton.Position = UDim2.new(0.5, -90, 0, 170 + (btnHeight + btnSpacing)*2)
	deselectAllButton.Text = "取消全部选中"
	deselectAllButton.TextSize = 14
	deselectAllButton.BackgroundColor3 = Color3.fromRGB(200, 100, 100)
	deselectAllButton.TextColor3 = Color3.new(1, 1, 1)
	deselectAllButton.Parent = scrollContent
	local moveToPlayerButton = Instance.new("TextButton")
	moveToPlayerButton.Name = "MoveToPlayer"
	moveToPlayerButton.Size = ctrlBtnSize
	moveToPlayerButton.Position = UDim2.new(0.5, -90, 0, 170 + (btnHeight + btnSpacing)*3)
	moveToPlayerButton.Text = "物体移至玩家"
	moveToPlayerButton.TextSize = 14
	moveToPlayerButton.BackgroundColor3 = Color3.fromRGB(100, 200, 100)
	moveToPlayerButton.TextColor3 = Color3.new(1, 1, 1)
	moveToPlayerButton.Parent = scrollContent
	local selectAllButton = Instance.new("TextButton")
	selectAllButton.Name = "SelectAll"
	selectAllButton.Size = ctrlBtnSize
	selectAllButton.Position = UDim2.new(0.5, -90, 0, 170 + (btnHeight + btnSpacing)*4)
	selectAllButton.Text = "一键全选物体"
	selectAllButton.TextSize = 14
	selectAllButton.BackgroundColor3 = Color3.fromRGB(255, 150, 0)
	selectAllButton.TextColor3 = Color3.new(1, 1, 1)
	selectAllButton.Parent = scrollContent
	local orbitButton = Instance.new("TextButton")
	orbitButton.Name = "OrbitPlayer"
	orbitButton.Size = ctrlBtnSize
	orbitButton.Position = UDim2.new(0.5, -90, 0, 170 + (btnHeight + btnSpacing)*5)
	orbitButton.Text = "物体围绕玩家"
	orbitButton.TextSize = 14
	orbitButton.BackgroundColor3 = Color3.fromRGB(150, 100, 255)
	orbitButton.TextColor3 = Color3.new(1, 1, 1)
	orbitButton.Parent = scrollContent
	-- 4. 移动方向区（y=420，网格排列，更整齐）
	local directionLabel = createSectionLabel("移動方向 (基於視角)", 420)
	local dirBtnSize = UDim2.new(0, 50, 0, 35)  -- 缩小方向按钮尺寸
	local directions = {
		{name = "向上", dir = Vector3.new(0, 1, 0), pos = UDim2.new(0.5, -25, 0, 450)},
		{name = "向下", dir = Vector3.new(0, -1, 0), pos = UDim2.new(0.5, -25, 0, 450 + dirBtnSize.Y.Offset + btnSpacing)},
		{name = "向前", dir = Vector3.new(0, 0, 1), pos = UDim2.new(0.3, -25, 0, 450)},
		{name = "向後", dir = Vector3.new(0, 0, -1), pos = UDim2.new(0.7, -25, 0, 450)},
		{name = "向左", dir = Vector3.new(-1, 0, 0), pos = UDim2.new(0.1, -25, 0, 450)},
		{name = "向右", dir = Vector3.new(1, 0, 0), pos = UDim2.new(0.9, -25, 0, 450)}
	}
	for i, dirInfo in ipairs(directions) do
		local button = Instance.new("TextButton")
		button.Name = dirInfo.name
		button.Size = dirBtnSize
		button.Position = dirInfo.pos
		button.Text = dirInfo.name
		button.TextSize = 12
		button.BackgroundColor3 = Color3.fromRGB(100, 100, 200)
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Parent = scrollContent
		button.MouseButton1Click:Connect(function()
			_G.moveDirection = getCameraRelativeDirection(dirInfo.dir)
			UpdatePartMovement()
			local originalColor = button.BackgroundColor3
			button.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
			delay(0.2, function()
				button.BackgroundColor3 = originalColor
			end)
		end)
	end
	-- 5. 翻轉控制區（y=550，居中排列）
	local flipLabel = createSectionLabel("翻轉控制", 550)
	local flipBtnSize = UDim2.new(0, 70, 0, 35)
	local flipButtons = {
		{name = "左翻轉", axis = "Y", value = -1, pos = UDim2.new(0.3, -35, 0, 580)},
		{name = "右翻轉", axis = "Y", value = 1, pos = UDim2.new(0.7, -35, 0, 580)},
		{name = "上翻轉", axis = "X", value = 1, pos = UDim2.new(0.5, -35, 0, 580 - flipBtnSize.Y.Offset - btnSpacing)},
		{name = "下翻轉", axis = "X", value = -1, pos = UDim2.new(0.5, -35, 0, 580 + flipBtnSize.Y.Offset + btnSpacing)}
	}
	for i, flipInfo in ipairs(flipButtons) do
		local button = Instance.new("TextButton")
		button.Name = flipInfo.name
		button.Size = flipBtnSize
		button.Position = flipInfo.pos
		button.Text = flipInfo.name
		button.TextSize = 12
		button.BackgroundColor3 = Color3.fromRGB(200, 100, 100)
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Parent = scrollContent
		button.MouseButton1Click:Connect(function()
			if flipInfo.axis == "X" then _G.flipX = flipInfo.value end
			if flipInfo.axis == "Y" then _G.flipY = flipInfo.value end
			if flipInfo.axis == "Z" then _G.flipZ = flipInfo.value end
			UpdatePartMovement()
			local originalColor = button.BackgroundColor3
			button.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
			delay(0.2, function()
				button.BackgroundColor3 = originalColor
			end)
		end)
	end
	-- 6. 關閉面板按鈕（y=670，底部居中）
	local closeButton = Instance.new("TextButton")
	closeButton.Name = "ClosePanel"
	closeButton.Size = ctrlBtnSize
	closeButton.Position = UDim2.new(0.5, -90, 0, 670)
	closeButton.Text = "關閉面板"
	closeButton.TextSize = 14
	closeButton.BackgroundColor3 = Color3.fromRGB(200, 100, 100)
	closeButton.TextColor3 = Color3.new(1, 1, 1)
	closeButton.Parent = scrollContent
	-- 原選擇模式與輸入邏輯（不变）
	local selectMode = false
	local function onMouseClick()
		if not selectMode then return end
		local targetPart = getTargetPart()
		if targetPart then
			SelectPart(targetPart)
		end
	end
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			onMouseClick()
		end
	end)
	-- 原按鈕功能綁定（不变）
	scaleUpButton.MouseButton1Click:Connect(function()
		uiScale.Scale = math.min(uiScale.Scale + 0.1, 1.5)
		scaleLabel.Text = "UI大小: " .. string.format("%.1f", uiScale.Scale)
		local originalColor = scaleUpButton.BackgroundColor3
		scaleUpButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
		delay(0.2, function()
			scaleUpButton.BackgroundColor3 = originalColor
		end)
	end)
	scaleDownButton.MouseButton1Click:Connect(function()
		uiScale.Scale = math.max(uiScale.Scale - 0.1, 0.5)
		scaleLabel.Text = "UI大小: " .. string.format("%.1f", uiScale.Scale)
		local originalColor = scaleDownButton.BackgroundColor3
		scaleDownButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
		delay(0.2, function()
			scaleDownButton.BackgroundColor3 = originalColor
		end)
	end)
	speedUpButton.MouseButton1Click:Connect(function()
		_G.floatSpeed = math.clamp(_G.floatSpeed + 5, 1, 100)
		speedLabel.Text = "速度: " .. _G.floatSpeed
		UpdatePartMovement()
		local originalColor = speedUpButton.BackgroundColor3
		speedUpButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
		delay(0.2, function()
			speedUpButton.BackgroundColor3 = originalColor
		end)
	end)
	speedDownButton.MouseButton1Click:Connect(function()
		_G.floatSpeed = math.clamp(_G.floatSpeed - 5, 1, 100)
		speedLabel.Text = "速度: " .. _G.floatSpeed
		UpdatePartMovement()
		local originalColor = speedDownButton.BackgroundColor3
		speedDownButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
		delay(0.2, function()
			speedDownButton.BackgroundColor3 = originalColor
		end)
	end)
	stopButton.MouseButton1Click:Connect(function()
		_G.floatSpeed = 0
		UpdatePartMovement()
		speedLabel.Text = "速度: " .. _G.floatSpeed
		local originalColor = stopButton.BackgroundColor3
		stopButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
		delay(0.2, function()
			stopButton.BackgroundColor3 = originalColor
		end)
	end)
	stopFlipButton.MouseButton1Click:Connect(function()
		StopFlip()
		local originalColor = stopFlipButton.BackgroundColor3
		stopFlipButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
		delay(0.2, function()
			stopFlipButton.BackgroundColor3 = originalColor
		end)
	end)
	deselectAllButton.MouseButton1Click:Connect(function()
		DeselectAllParts()
		local originalColor = deselectAllButton.BackgroundColor3
		deselectAllButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
		delay(0.2, function()
			deselectAllButton.BackgroundColor3 = originalColor
		end)
	end)
	moveToPlayerButton.MouseButton1Click:Connect(function()
		MoveToPlayer()
		local originalColor = moveToPlayerButton.BackgroundColor3
		moveToPlayerButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
		delay(0.2, function()
			moveToPlayerButton.BackgroundColor3 = originalColor
		end)
	end)
	selectModeButton.MouseButton1Click:Connect(function()
		selectMode = not selectMode
		if selectMode then
			selectModeButton.Text = "選擇模式: 開啟"
			selectModeButton.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
			print("選擇模式已開啟（可點擊物體添加/取消選擇）")
		else
			selectModeButton.Text = "選擇模式: 關閉"
			selectModeButton.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
			print("選擇模式已關閉")
		end
	end)
	closeButton.MouseButton1Click:Connect(function()
		controlPanel.Visible = false
		openPanelButton.Visible = true
		print("控制面板已關閉")
	end)
	openPanelButton.MouseButton1Click:Connect(function()
		controlPanel.Visible = true
		openPanelButton.Visible = false
		print("控制面板已打開")
	end)
	-- 绑定优化后的「一键全选」按钮功能
	selectAllButton.MouseButton1Click:Connect(function()
		SelectAllParts()
		local originalColor = selectAllButton.BackgroundColor3
		selectAllButton.BackgroundColor3 = Color3.fromRGB(255, 200, 0)
		delay(0.2, function()
			selectAllButton.BackgroundColor3 = originalColor
		end)
	end)
	-- 绑定「物体围绕玩家」按钮功能（不变）
	orbitButton.MouseButton1Click:Connect(function()
		toggleOrbit()
		local originalColor = orbitButton.BackgroundColor3
		orbitButton.BackgroundColor3 = _G.isOrbiting and Color3.fromRGB(255, 0, 0) or Color3.fromRGB(0, 255, 0)
		orbitButton.Text = _G.isOrbiting and "停止围绕玩家" or "物体围绕玩家"
		delay(0.2, function()
			orbitButton.BackgroundColor3 = originalColor
		end)
	end)
	return screenGui
end
-- 原錯誤處理（不变）
local success, err = pcall(function()
	CreateMobileGUI()
end)
if not success then
	warn("GUI建立失敗: " .. tostring(err))
	local errorMsg = Instance.new("Message")
	errorMsg.Text = "漂浮控制GUI初始化失敗: " .. tostring(err)
	errorMsg.Parent = Workspace
	delay(5, function()
		errorMsg:Destroy()
	end)
end
print("多物體漂浮控制腳本已載入成功! 「一键全选」支援所有文件夹、嵌套模型，新增「物体围绕玩家」功能。")
