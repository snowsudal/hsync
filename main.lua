-- H-SYNC SECURITY INTEGRATION v1.7.7 (SOLARA CACHE-BUSTING FAIL-SAFE ENGINE)
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")

-- [★ 외부 인증 서버 주소 설정]
local API_URL = "http://1.242.89.251:3000"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- 리모트 이벤트 경로 설정
local RBCL_REMOTES = ReplicatedStorage:WaitForChild("RBCL_REMOTES")
local ClientBallVisual = RBCL_REMOTES:WaitForChild("Pitching"):WaitForChild("ClientBallVisual")

-- 글로벌 설정 변수 (유저 최적 황금 감도 고정)
local _G = getgenv and getgenv() or _G
_G.AssistActive = false          
_G.AutoStrikeTestActive = false 
_G.ZoneKeeperActive = false      
_G.TrajectoryLineActive = false  
_G.AutoEActive = false           
_G.TimingOffset = -0.05         
_G.HeightOffset = -0.05         
_G.SideOffset = 0.00            
_G.CameraLiftPower = 2.5        

-- 원래 게임의 화면 강제 고정/회전 스크립트 정지
if getconnections then
    for _, connection in ipairs(getconnections(ClientBallVisual.OnClientEvent)) do
        connection:Disable()
    end
end

local StrikeZonePart = workspace:WaitForChild("strike_zone", 5):WaitForChild("strike", 5)
local TestTargetCFrame = nil
local UI_LOG_CONTAINER = {}
local LogScrollFrame = nil
local IsAuthenticated = false 

-- 전방 선언
local MainFrame = nil
local AuthGate = nil
local function LogToGate(txt, col) end 

-- 스트라이크 존 상시 고정 루프
RunService.Heartbeat:Connect(function()
    if IsAuthenticated and _G.ZoneKeeperActive and StrikeZonePart and StrikeZonePart.Parent then
        if StrikeZonePart.Transparency ~= 0.5 then StrikeZonePart.Transparency = 0.5 end
        if not StrikeZonePart.LocalTransparencyModifier or StrikeZonePart.LocalTransparencyModifier ~= 0 then
            StrikeZonePart.LocalTransparencyModifier = 0
        end
    end
end)

-- 인게임 하단 터미널 패널 로그 함수
local function AddUiLog(text)
    local timestamp = os.date("%X")
    local fullText = string.format("[%s] %s", timestamp, text)
    table.insert(UI_LOG_CONTAINER, fullText)
    if #UI_LOG_CONTAINER > 25 then table.remove(UI_LOG_CONTAINER, 1) end
    
    if LogScrollFrame then
        for _, child in ipairs(LogScrollFrame:GetChildren()) do if child:IsA("TextLabel") then child:Destroy() end end
        local yOffset = 0
        for i = #UI_LOG_CONTAINER, 1, -1 do
            local logLabel = Instance.new("TextLabel")
            logLabel.Size = UDim2.new(1, -10, 0, 22)
            logLabel.Position = UDim2.new(0, 5, 0, yOffset)
            logLabel.BackgroundTransparency = 1
            logLabel.TextColor3 = Color3.fromRGB(245, 245, 245) 
            logLabel.ZIndex = 5
            if string.find(UI_LOG_CONTAINER[i], "STRIKE") or string.find(UI_LOG_CONTAINER[i], "성공") or string.find(UI_LOG_CONTAINER[i], "진입") or string.find(UI_LOG_CONTAINER[i], "Loaded") then
                logLabel.TextColor3 = Color3.fromRGB(34, 211, 114) 
            elseif string.find(UI_LOG_CONTAINER[i], "BALL") or string.find(UI_LOG_CONTAINER[i], "차단") or string.find(UI_LOG_CONTAINER[i], "보류") or string.find(UI_LOG_CONTAINER[i], "Fail") or string.find(UI_LOG_CONTAINER[i], "다운") or string.find(UI_LOG_CONTAINER[i], "로그아웃") then
                logLabel.TextColor3 = Color3.fromRGB(251, 113, 113) 
            end
            logLabel.Text = UI_LOG_CONTAINER[i]
            logLabel.Font = Enum.Font.SourceSansBold 
            logLabel.TextSize = 14 
            logLabel.TextXAlignment = Enum.TextXAlignment.Left
            logLabel.Parent = LogScrollFrame
            yOffset = yOffset + 22
        end
        LogScrollFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset)
    end
end

-- [★ 핵심 수정: 캐시 버스팅이 결합된 실시간 오프라인 강제 추방 서킷]
local function StartHeartbeatLoop()
    task.spawn(function()
        while IsAuthenticated do
            task.wait(4) -- 4초 간격 정밀 감지
            if not IsAuthenticated then break end
            
            -- 주소 뒤에 매번 바뀌는 무작위 숫자(?nocache=시간)를 강제 주입하여 엔진 캐시를 완전히 무력화합니다.
            local cacheBuster = tostring(os.clock()):gsub("%.", "")
            local pingURL = string.format("%s/heartbeat?userId=%s&nocache=%s", API_URL, tostring(LocalPlayer.UserId), cacheBuster)
            
            local success, response = pcall(function()
                return game:HttpGetAsync(pingURL)
            end)
            
            -- 엔진 캐시가 파쇄되었기 때문에 서버가 꺼지면 무조건 success = false 혹은 에러 문구가 떨어집니다.
            if not success or not response or string.find(tostring(response), "expired") or tostring(response) == "" then
                IsAuthenticated = false
                
                -- 모든 불법 치트 변수 진공 청소 및 인접 메모리 강제 격리
                _G.AssistActive = false          
                _G.AutoStrikeTestActive = false 
                _G.ZoneKeeperActive = false      
                _G.TrajectoryLineActive = false  
                _G.AutoEActive = false           
                TestTargetCFrame = nil
                
                -- 즉시 레이아웃 가시성 통제 및 초기 로그인 화면 게이트 오버레이
                task.spawn(function()
                    if AuthGate and MainFrame then
                        AuthGate.Visible = true
                        LogToGate("인증 서버 오프라인", Color3.fromRGB(251, 113, 113))
                        LogToGate("[aUTH] Locked", Color3.fromRGB(251, 113, 113))
                    end
                    AddUiLog("[aUTH] Logout.")
                end)
                break
            end
        end
    end)
end

-- 걸치는 공 인지를 위한 보더라인 마진 보정 판정 함수
local function CheckIsStrike(finalPos)
    if not StrikeZonePart then return false end
    local localPos = StrikeZonePart.CFrame:PointToObjectSpace(finalPos)
    local zoneSize = StrikeZonePart.Size
    local ballRadiusMargin = 0.30 
    local isWithinX = math.abs(localPos.X) <= ((zoneSize.X / 2) + ballRadiusMargin)
    local isWithinY = math.abs(localPos.Y) <= ((zoneSize.Y / 2) + ballRadiusMargin)
    return isWithinX and isWithinY
end

-- 실시간 공 궤적 가이드 레이저선 그리기 함수
local function DrawBallTrajectory(startPos, endPos, duration, isStrike)
    if not _G.TrajectoryLineActive then return end
    
    local linePart = Instance.new("Part")
    linePart.Name = "BallTrajectoryLine"
    linePart.Anchored = true
    linePart.CanCollide = false
    linePart.Material = Enum.Material.Neon
    linePart.Transparency = 0.3
    
    linePart.Color = isStrike and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(180, 50, 255)
    
    local distance = (endPos - startPos).Magnitude
    linePart.Size = Vector3.new(0.08, 0.08, distance)
    linePart.CFrame = CFrame.lookAt(startPos, endPos) * CFrame.new(0, 0, -distance / 2)
    linePart.Parent = workspace
    
    local lineTween = TweenService:Create(linePart, TweenInfo.new(duration + 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
        Size = Vector3.new(0, 0, distance),
        Transparency = 1
    })
    lineTween:Play()
    lineTween.Completed:Connect(function() linePart:Destroy() end)
end

-- 시각 마커 생성 함수
local function CreateSmartMarker(position, speed, isStrike)
    if not IsAuthenticated or not _G.AssistActive then return end
    if workspace:FindFirstChild("BallPredictionMarker") then workspace.BallPredictionMarker:Destroy() end
    
    local marker = Instance.new("Part")
    marker.Name = "BallPredictionMarker"
    marker.Shape = Enum.PartType.Ball
    marker.Size = Vector3.new(0.35, 0.35, 0.35) 
    marker.Position = position 
    marker.Anchored, marker.CanCollide, marker.Material, marker.Transparency = true, false, Enum.Material.Neon, 0.2
    marker.Parent = workspace
    
    local startColor, hitColor = Color3.fromRGB(150, 0, 255), Color3.fromRGB(0, 100, 255)
    if isStrike then startColor, hitColor = Color3.fromRGB(0, 255, 0), Color3.fromRGB(255, 0, 0) end
    marker.Color = startColor
    
    local baseDuration = 1.0 / (speed / 100)
    local duration = math.max(0.05, baseDuration + _G.TimingOffset)
    local tween1 = TweenService:Create(marker, TweenInfo.new(duration * 0.6, Enum.EasingStyle.Linear), {Color = hitColor})
    local logTween2 = TweenService:Create(marker, TweenInfo.new(duration * 0.4, Enum.EasingStyle.Linear), {Size = Vector3.new(0.5, 0.5, 0.5)})
    tween1:Play()
    tween1.Completed:Connect(function() logTween2:Play() end)
    task.delay(duration + 1.5, function() if marker and marker.Parent then marker:Destroy() end end)
end

-- H-SYNC 6.0세대 완전체 휴먼 키네틱 엔진 본체
local function ExecuteAutomatedTest(position, speed, isStrike)
    if not IsAuthenticated then return end
    
    local baseDuration = 1.0 / (speed / 100)
    local directionTimingModifier = (_G.SideOffset * 0.05)
    local arrivalDuration = math.max(0.01, baseDuration + _G.TimingOffset + directionTimingModifier)
    
    if not _G.AutoStrikeTestActive then 
        AddUiLog(string.format("speed: %s km/h", tostring(speed)))
        return 
    end
    if not isStrike then 
        AddUiLog(string.format("BALL (%s km/h)", tostring(speed))) 
        return 
    end
    
    local finalAimPosition = position + Vector3.new(_G.SideOffset, _G.HeightOffset, 0)
    TestTargetCFrame = CFrame.new(finalAimPosition)
    
    local timer = 0
    local topbarOffset = GuiService:GetGuiInset().Y
    local lockConnection
    local isSwinging = false 
    
    local mouseLocation = UserInputService:GetMouseLocation()
    local realStartX = mouseLocation.X
    local realStartY = mouseLocation.Y
    
    local randomSideSign = (realStartX > 100) and -1 or 1
    local controlPointX = realStartX + (math.random(15, 30) * randomSideSign)
    local controlPointY = realStartY - math.random(10, 20)
    
AddUiLog(string.format("STRIKE %s km/h", tostring(speed)))
lockConnection = RunService.RenderStepped:Connect(function(deltaTime)
if not _G.AutoStrikeTestActive then lockConnection:Disconnect() TestTargetCFrame = nil return end
timer = timer + deltaTime
local screenPos, onScreen = Camera:WorldToScreenPoint(finalAimPosition)
if onScreen then
local targetX = screenPos.X
local targetY = screenPos.Y + topbarOffset
local progress = math.clamp(timer / arrivalDuration, 0, 1)
local smoothAlpha = 0
local visualLatency = 0.22
if progress >= visualLatency then
local humanProgress = (progress - visualLatency) / (1 - visualLatency)
smoothAlpha = math.pow(humanProgress, 4)
end
local tensionFluctuation = smoothAlpha + (math.sin(smoothAlpha * math.pi) * 0.02 * math.sin(timer * 60))
local boundedAlpha = math.clamp(tensionFluctuation, 0, 1)
local b1_X = realStartX + (controlPointX - realStartX) * boundedAlpha
local b1_Y = realStartY + (controlPointY - realStartY) * boundedAlpha
local b2_X = controlPointX + (targetX - controlPointX) * boundedAlpha
local b2_Y = controlPointY + (targetY - controlPointY) * boundedAlpha
local currentX = b1_X + (b2_X - b1_X) * boundedAlpha
local currentY = b1_Y + (b2_Y - b1_Y) * boundedAlpha
VirtualInputManager:SendMouseMoveEvent(currentX, currentY, game)
end
if timer >= arrivalDuration and not isSwinging then
isSwinging = true
lockConnection:Disconnect()
if onScreen then
local finalX = screenPos.X
local finalY = screenPos.Y + topbarOffset
VirtualInputManager:SendMouseMoveEvent(finalX, finalY, game)
VirtualInputManager:SendMouseButtonEvent(finalX, finalY, 0, true, game, 0)
local centerForceModifier = 1.0
if math.abs(_G.SideOffset) < 0.05 then
centerForceModifier = 2.85
end
local swingVectorX = (finalX - realStartX) * 0.12
local swingVectorY = ((finalY - realStartY) - (_G.CameraLiftPower * 25 * centerForceModifier)) * 0.12
task.spawn(function()
for i = 1, 6 do
local followAlpha = i / 6
local followX = finalX + (swingVectorX * (1 - followAlpha))
local followY = finalY + (swingVectorY * (1 - followAlpha))
VirtualInputManager:SendMouseMoveEvent(followX, followY, game)
RunService.RenderStepped:Wait()
end
VirtualInputManager:SendMouseButtonEvent(finalX, finalY, 0, false, game, 0)
TestTargetCFrame = nil
end)
else
TestTargetCFrame = nil
end
end
end)
end
-- 🖥️ Apple UI 빌드 섹션
if CoreGui:FindFirstChild("RBCL_MasterGui") then CoreGui.RBCL_MasterGui:Destroy() end
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "RBCL_MasterGui"
ScreenGui.Parent = CoreGui
MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 280, 0, 560)
MainFrame.Position = UDim2.new(0.02, 0, 0.18, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
MainFrame.BackgroundTransparency = 0.15
MainFrame.BorderSizePixel, MainFrame.Active, MainFrame.Draggable = 0, true, true
MainFrame.Parent = ScreenGui
local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color, MainStroke.Transparency, MainStroke.Thickness = Color3.fromRGB(255, 255, 255), 0.92, 1
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)
AuthGate = Instance.new("Frame")
AuthGate.Size = UDim2.new(1, 0, 1, 0)
AuthGate.BackgroundColor3 = Color3.fromRGB(20, 20, 23)
AuthGate.BorderSizePixel, AuthGate.ZIndex = 0, 10
AuthGate.Parent = MainFrame
Instance.new("UICorner", AuthGate).CornerRadius = UDim.new(0, 12)
local GateStroke = Instance.new("UIStroke", AuthGate)
GateStroke.Color, GateStroke.Transparency, GateStroke.Thickness = Color3.fromRGB(255, 255, 255), 0.92, 1
local GateTitle = Instance.new("TextLabel")
GateTitle.Size = UDim2.new(1, 0, 0, 40)
GateTitle.Position = UDim2.new(0, 0, 0, 40)
GateTitle.BackgroundTransparency, GateTitle.TextColor3, GateTitle.Text, GateTitle.Font, GateTitle.TextSize, GateTitle.ZIndex = 1, Color3.fromRGB(255, 255, 255), "치토프라이빗", Enum.Font.SourceSansBold, 18, 11
GateTitle.Parent = AuthGate
local GateSub = Instance.new("TextLabel")
GateSub.Size = UDim2.new(1, 0, 0, 20)
GateSub.Position = UDim2.new(0, 0, 0, 75)
GateSub.BackgroundTransparency, GateSub.TextColor3, GateSub.Text, GateSub.Font, GateSub.TextSize, GateSub.ZIndex = 1, Color3.fromRGB(142, 142, 147), "", Enum.Font.SourceSans, 11, 11
GateSub.Parent = AuthGate
local InputBox = Instance.new("TextBox")
InputBox.Size = UDim2.new(1, -40, 0, 36)
InputBox.Position = UDim2.new(0, 20, 0, 125)
InputBox.BackgroundColor3, InputBox.TextColor3, InputBox.PlaceholderText, InputBox.PlaceholderColor3, InputBox.Font, InputBox.TextSize, InputBox.Text, InputBox.ClearTextOnFocus, InputBox.ZIndex = Color3.fromRGB(28, 28, 30), Color3.fromRGB(255, 255, 255), "Password.", Color3.fromRGB(99, 99, 102), Enum.Font.Code, 13, "", false, 11
InputBox.Parent = AuthGate
Instance.new("UICorner", InputBox).CornerRadius = UDim.new(0, 8)
local BoxStroke = Instance.new("UIStroke", InputBox)
BoxStroke.Color, BoxStroke.Transparency = Color3.fromRGB(255, 255, 255), 0.9
local GateLogFrame = Instance.new("ScrollingFrame")
GateLogFrame.Size = UDim2.new(1, -40, 0, 140)
GateLogFrame.Position = UDim2.new(0, 20, 0, 175)
GateLogFrame.BackgroundColor3, GateLogFrame.BackgroundTransparency, GateLogFrame.BorderSizePixel, GateLogFrame.ZIndex, GateLogFrame.ScrollBarThickness = Color3.fromRGB(12, 12, 14), 0.3, 0, 11, 0
GateLogFrame.Parent = AuthGate
Instance.new("UICorner", GateLogFrame).CornerRadius = UDim.new(0, 6)
local GateLogStroke = Instance.new("UIStroke", GateLogFrame)
GateLogStroke.Color, GateLogStroke.Transparency = Color3.fromRGB(255, 255, 255), 0.94
LogToGate = function(txt, col)
for _, child in ipairs(GateLogFrame:GetChildren()) do
if child:IsA("TextLabel") then child.Position = child.Position + UDim2.new(0, 0, 0, 18) end
end
local label = Instance.new("TextLabel")
label.Size, label.Position, label.BackgroundTransparency, label.TextColor3, label.Text, label.Font, label.TextSize, label.TextXAlignment, label.ZIndex = UDim2.new(1, -10, 0, 18), UDim2.new(0, 5, 0, 0), 1, col or Color3.fromRGB(220, 220, 225), string.format("[%s] %s", os.date("%X"), txt), Enum.Font.SourceSansBold, 13, Enum.TextXAlignment.Left, 12
label.Parent = GateLogFrame
end
local SubmitButton = Instance.new("TextButton")
SubmitButton.Size = UDim2.new(1, -40, 0, 36)
SubmitButton.Position = UDim2.new(0, 20, 0, 330)
SubmitButton.BackgroundColor3, SubmitButton.TextColor3, SubmitButton.Text, SubmitButton.Font, SubmitButton.TextSize, SubmitButton.ZIndex = Color3.fromRGB(0, 122, 255), Color3.fromRGB(255, 255, 255), "verify", Enum.Font.SourceSansBold, 13, 11
SubmitButton.Parent = AuthGate
Instance.new("UICorner", SubmitButton).CornerRadius = UDim.new(0, 8)
task.wait(1)
LogToGate("[Load] ModuleImport. Waiting...", Color3.fromRGB(160, 190, 220))
SubmitButton.MouseButton1Click:Connect(function()
local text = string.gsub(InputBox.Text, "^%s*(.-)%s*$", "%1")
if text == "" then LogToGate("입력값이 비어 있습니다.", Color3.fromRGB(248, 113, 113)) return end
LogToGate("[Load] Connect By Server...", Color3.fromRGB(255, 255, 0))
task.wait(0.5)
LogToGate("[Load] Authenticating...", Color3.fromRGB(255, 255, 0))
task.wait(1.5)
local queryURL = string.format(
"%s/verify?key=%s&username=%s&userId=%s",
API_URL,
HttpService:UrlEncode(tostring(text)),
HttpService:UrlEncode(tostring(LocalPlayer.Name)),
HttpService:UrlEncode(tostring(LocalPlayer.UserId))
)
if request then
local success, response = pcall(function()
return request({
Url = queryURL,
Method = "GET"
})
end)
if success and response then
local responseCode = response.StatusCode
if responseCode == 200 or responseCode == "200" then
local jsonSuccess, responseData = pcall(function() return HttpService:JSONDecode(response.Body) end)
if jsonSuccess and responseData and responseData.success == true then
LogToGate("[Load] Verify! Load ServerEvent...", Color3.fromRGB(255, 255, 0))
task.wait(0.5)
IsAuthenticated = true
AuthGate.Visible = false
AddUiLog("[Load] Loaded!", Color3.fromRGB(255, 255, 0))
-- 캐시 파쇄형 허브 감지 서킷 시동
StartHeartbeatLoop()
else
local reason = responseData and responseData.message or "인증키가 올바르지 않습니다."
LogToGate("[Fail] " .. reason, Color3.fromRGB(248, 113, 113))
end
else
LogToGate("[Fail] HTTP 에러 코드: " .. tostring(responseCode), Color3.fromRGB(248, 113, 113))
end
else
LogToGate("[Error] 소켓 통신 전송 예외 발생.", Color3.fromRGB(248, 113, 113))
end
else
LogToGate("[Error] Solara 환경이 아닙니다.", Color3.fromRGB(248, 113, 113))
end
end)
local ClockLabel = Instance.new("TextLabel")
ClockLabel.Size = UDim2.new(1, -20, 0, 30)
ClockLabel.Position = UDim2.new(0, 10, 0, 10)
ClockLabel.BackgroundTransparency, ClockLabel.TextColor3, ClockLabel.Text, ClockLabel.Font, ClockLabel.TextSize, ClockLabel.ZIndex = 1, Color3.fromRGB(235, 235, 240), os.date("%Y-%m-%d  %X"), Enum.Font.SourceSans, 14, 1
ClockLabel.Parent = MainFrame
task.spawn(function()
while task.wait(1) do
if ClockLabel and ClockLabel.Parent then ClockLabel.Text = os.date("%Y-%m-%d  %X") else break end
end
end)
local CenterDivider = Instance.new("Frame")
CenterDivider.Size = UDim2.new(1, -30, 0, 1)
CenterDivider.Position = UDim2.new(0, 15, 0, 42)
CenterDivider.BackgroundColor3, CenterDivider.BackgroundTransparency, CenterDivider.ZIndex = Color3.fromRGB(255, 255, 255), 0.9, 1
CenterDivider.Parent = MainFrame
local ButtonInstances = {}
local function CreateAppleButton(textOn, textOff, yPos, isActive, onClickCallback)
local button = Instance.new("TextButton")
button.Size = UDim2.new(1, -30, 0, 30)
button.Position = UDim2.new(0, 15, 0, yPos)
button.Font, button.TextSize, button.BorderSizePixel, button.ZIndex = Enum.Font.SourceSansBold, 12, 0, 1
button.Parent = MainFrame
Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
local stroke = Instance.new("UIStroke", button)
stroke.Thickness, stroke.Transparency = 1, 0.85
local function UpdateButtonStyle(state)
if state then
button.Text = textOn
button.BackgroundColor3, button.TextColor3, stroke.Color = Color3.fromRGB(0, 122, 255), Color3.fromRGB(255, 255, 255), Color3.fromRGB(0, 122, 255)
else
button.Text = textOff
button.BackgroundColor3, button.TextColor3, stroke.Color = Color3.fromRGB(38, 38, 42), Color3.fromRGB(160, 160, 165), Color3.fromRGB(255, 255, 255)
end
end
UpdateButtonStyle(isActive)
button.MouseButton1Click:Connect(function()
local nextState = onClickCallback()
UpdateButtonStyle(nextState)
button.Size = UDim2.new(1, -34, 0, 28)
task.wait(0.05)
button.Size = UDim2.new(1, -30, 0, 30)
end)
return {
Instance = button,
Update = UpdateButtonStyle
}
end
ButtonInstances["ESP"] = CreateAppleButton("[ON] ESP", "[OFF] ESP", 50, _G.AssistActive, function()
_G.AssistActive = not _G.AssistActive
return _G.AssistActive
end)
ButtonInstances["Aimbot"] = CreateAppleButton("[ON] Aimbot", "[OFF] Aimbot", 86, _G.AutoStrikeTestActive, function()
_G.AutoStrikeTestActive = not _G.AutoStrikeTestActive
if not _G.AutoStrikeTestActive then TestTargetCFrame = nil end
return _G.AutoStrikeTestActive
end)
ButtonInstances["StrikeZone"] = CreateAppleButton("[ON] StrikeZone", "[OFF] StrikeZone", 122, _G.ZoneKeeperActive, function()
--_G.ZoneKeeperActive = not _G.ZoneKeeperActive
return _G.ZoneKeeperActive
end)
ButtonInstances["Trajectory"] = CreateAppleButton("[ON] 궤적", "[OFF] 궤적", 158, _G.TrajectoryLineActive, function()
--_G.TrajectoryLineActive = not _G.TrajectoryLineActive
return _G.TrajectoryLineActive
end)
ButtonInstances["AutoBP"] = CreateAppleButton("[ON] Auto BP", "[OFF] Auto BP", 194, _G.AutoEActive, function()
_G.AutoEActive = not _G.AutoEActive
if _G.AutoEActive then
_G.AutoStrikeTestActive = true
if ButtonInstances["Aimbot"] then
ButtonInstances["Aimbot"].Update(true)
end
end
return _G.AutoEActive
end)
local function CreateAppleController(labelText, globalKey, yPos, step, isAbsolute)
local controlFrame = Instance.new("Frame")
controlFrame.Size = UDim2.new(1, -30, 0, 24)
controlFrame.Position = UDim2.new(0, 15, 0, yPos)
controlFrame.BackgroundTransparency, controlFrame.ZIndex = 1, 1
controlFrame.Parent = MainFrame
local dataLabel = Instance.new("TextLabel")
dataLabel.Size, dataLabel.Position, dataLabel.BackgroundTransparency, dataLabel.TextColor3, dataLabel.Font, dataLabel.TextSize, dataLabel.TextXAlignment, dataLabel.ZIndex = UDim2.new(0, 130, 1, 0), UDim2.new(0, 48, 0, 0), 1, Color3.fromRGB(210, 210, 215), Enum.Font.SourceSansBold, 12, Enum.TextXAlignment.Left, 1
dataLabel.Text = string.format("%s:  %.2f", labelText, isAbsolute and math.abs(_G[globalKey]) or _G[globalKey])
dataLabel.Parent = controlFrame
local minusBtn = Instance.new("TextButton")
minusBtn.Size, minusBtn.Position, minusBtn.BackgroundColor3, minusBtn.TextColor3, minusBtn.Font, minusBtn.TextSize, minusBtn.ZIndex = UDim2.new(0, 32, 1, -2), UDim2.new(0, 0, 0, 1), Color3.fromRGB(44, 44, 46), Color3.fromRGB(235, 235, 245), Enum.Font.SourceSans, 14, 1
minusBtn.Parent = controlFrame
Instance.new("UICorner", minusBtn).CornerRadius = UDim.new(0, 6)
local plusBtn = Instance.new("TextButton")
plusBtn.Size, plusBtn.Position, plusBtn.BackgroundColor3, plusBtn.TextColor3, plusBtn.Text, plusBtn.Font, plusBtn.TextSize, plusBtn.ZIndex = UDim2.new(0, 32, 1, -2), UDim2.new(1, -32, 0, 1), Color3.fromRGB(44, 44, 46), Color3.fromRGB(235, 235, 245), "+", Enum.Font.SourceSans, 14, 1
plusBtn.Parent = controlFrame
Instance.new("UICorner", plusBtn).CornerRadius = UDim.new(0, 6)
if globalKey == "SideOffset" then minusBtn.Text, plusBtn.Text = "◀", "▶"
elseif globalKey == "HeightOffset" then minusBtn.Text, plusBtn.Text = "▼", "▲"
elseif globalKey == "CameraLiftPower" then minusBtn.Text, plusBtn.Text = "↷", "↱"
else minusBtn.Text, plusBtn.Text = "-", "+" end
minusBtn.MouseButton1Click:Connect(function()
_G[globalKey] = _G[globalKey] - step
dataLabel.Text = string.format("%s:  %.2f", labelText, isAbsolute and math.abs(_G[globalKey]) or _G[globalKey])
end)
plusBtn.MouseButton1Click:Connect(function()
if globalKey == "HeightOffset" then _G[globalKey] = math.min(0, _G[globalKey] + step) else _G[globalKey] = _G[globalKey] + step end
dataLabel.Text = string.format("%s:  %.2f", labelText, isAbsolute and math.abs(_G[globalKey]) or _G[globalKey])
end)
end
CreateAppleController("시간 보정", "TimingOffset", 234, 0.01, false)
CreateAppleController("높이(밑)", "HeightOffset", 262, 0.01, true)
CreateAppleController("타구 방향(X)", "SideOffset", 290, 0.01, false)
CreateAppleController("스윙 각도(Y)", "CameraLiftPower", 318, 0.5, false)
local TerminalHeader = Instance.new("TextLabel")
TerminalHeader.Size, TerminalHeader.Position, TerminalHeader.BackgroundTransparency, TerminalHeader.TextColor3, TerminalHeader.Text, TerminalHeader.Font, TerminalHeader.TextSize, TerminalHeader.TextXAlignment, TerminalHeader.ZIndex = UDim2.new(1, -30, 0, 20), UDim2.new(0, 15, 0, 350), 1, Color3.fromRGB(142, 142, 147), "LOG", Enum.Font.SourceSansBold, 11, Enum.TextXAlignment.Left, 1
TerminalHeader.Parent = MainFrame
LogScrollFrame = Instance.new("ScrollingFrame")
LogScrollFrame.Size, LogScrollFrame.Position, LogScrollFrame.BackgroundColor3, LogScrollFrame.BackgroundTransparency, LogScrollFrame.BorderSizePixel, LogScrollFrame.ScrollBarThickness, LogScrollFrame.ZIndex = UDim2.new(1, -30, 0, 160), UDim2.new(0, 15, 0, 373), Color3.fromRGB(0, 0, 0), 0.4, 0, 2, 1
LogScrollFrame.Parent = MainFrame
Instance.new("UICorner", LogScrollFrame).CornerRadius = UDim.new(0, 8)
if hookmetamethod then
local originalIndex
originalIndex = hookmetamethod(game, "__index", function(self, key)
if IsAuthenticated and _G.AutoStrikeTestActive and self == Mouse and TestTargetCFrame then
if key == "Hit" then return TestTargetCFrame elseif key == "Target" then return StrikeZonePart end
end
return originalIndex(self, key)
end)
end
ClientBallVisual.OnClientEvent:Connect(function(v1, v2, v3, v4, v5, v6, v7)
if not IsAuthenticated or not v1 or not v2 then return end
local isStrike = CheckIsStrike(v2)
local baseDuration = 1.0 / (v5 / 100)
DrawBallTrajectory(v1, v2, baseDuration, isStrike)
CreateSmartMarker(v2, v5, isStrike)
ExecuteAutomatedTest(v2, v5, isStrike)
end)
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
if gameProcessedEvent then return end
if UserInputService:GetFocusedTextBox() then return end
if input.KeyCode == Enum.KeyCode.U then
if UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) then
if MainFrame then
MainFrame.Visible = not MainFrame.Visible
MainFrame.Active = MainFrame.Visible
end
end
end
end)
task.spawn(function()
while true do
task.wait(8)
if _G.AutoEActive and not UserInputService:GetFocusedTextBox() then
VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
task.wait(0.05)
VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end
end
end)