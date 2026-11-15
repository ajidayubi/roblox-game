--!strict
-- TowerClient: everything the player sees and presses.
-- Builds the HUD from HudBuilder, listens to the server's remotes for the
-- timer, coins, checkpoints, hazards, wins and the leaderboard, and owns
-- the sprint key. It never decides a score: it only renders what the
-- server tells it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local HudBuilder = require(script.Parent:WaitForChild("HudBuilder"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("TowerRemotes")
local TimerTick = remotes:WaitForChild("TimerTick") :: RemoteEvent
local CoinCollected = remotes:WaitForChild("CoinCollected") :: RemoteEvent
local CheckpointReached = remotes:WaitForChild("CheckpointReached") :: RemoteEvent
local HazardHit = remotes:WaitForChild("HazardHit") :: RemoteEvent
local PlayerWon = remotes:WaitForChild("PlayerWon") :: RemoteEvent
local RoundOver = remotes:WaitForChild("RoundOver") :: RemoteEvent
local LeaderboardUpdate = remotes:WaitForChild("LeaderboardUpdate") :: RemoteEvent
local PersonalBest = remotes:WaitForChild("PersonalBest") :: RemoteEvent
local PlayAgain = remotes:WaitForChild("PlayAgain") :: RemoteEvent

-- ScreenGui: IgnoreGuiInset keeps the top bar clear of Roblox's own menu.
local gui = Instance.new("ScreenGui")
gui.Name = "TowerClimbGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local topBar = HudBuilder.buildTopBar(gui)
local leaderboardRows = HudBuilder.buildLeaderboardPanel(gui)
local toast = HudBuilder.buildToast(gui)
local startScreen = HudBuilder.buildStartScreen(gui)
local endScreen = HudBuilder.buildEndScreen(gui)
local hazardFlash = HudBuilder.buildHazardFlash(gui)

local coins = 0
local maxHeight = 0
local personalBest = 0
local currentStage = 0
local timeLeft = GameConfig.ROUND_TIME_SECONDS
local won = false

local function formatTime(seconds: number): string
	local minutes = math.floor(seconds / 60)
	local rest = seconds % 60
	return string.format("%d:%02d", minutes, rest)
end

local function refreshTopBar()
	topBar.time.Text = "⏱ " .. formatTime(timeLeft)
	topBar.coins.Text = "🪙 " .. tostring(coins)
	topBar.height.Text = "📏 " .. tostring(maxHeight) .. "m"
	topBar.stage.Text = string.format("Stage %d/5", math.max(currentStage, 1))
	if timeLeft <= 30 then
		topBar.time.TextColor3 = GameConfig.HUD_DANGER
	else
		topBar.time.TextColor3 = GameConfig.HUD_TEXT
	end
end

local toastThread: thread? = nil
local function showToast(message: string, color: Color3)
	toast.Text = message
	toast.TextColor3 = color
	toast.Visible = true
	if toastThread ~= nil then
		task.cancel(toastThread)
	end
	toastThread = task.spawn(function()
		task.wait(2)
		toast.Visible = false
	end)
end

local function pulseCoins()
	local tweenInfo = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
	TweenService:Create(topBar.coins, tweenInfo, { TextSize = 30 }):Play()
	task.delay(0.3, function()
		topBar.coins.TextSize = 24
	end)
end

local function showEndScreen(title: string, stats: string)
	endScreen.title.Text = title
	endScreen.stats.Text = stats
	endScreen.frame.Visible = true
end

local function hideEndScreen()
	endScreen.frame.Visible = false
end

-- Sprint: hold Shift to run faster, release to walk. Read with IsKeyDown
-- so the camera's arrow-key handling never swallows the input.
local sprinting = false
local function applySpeed()
	local character = player.Character
	if character == nil then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = if sprinting then GameConfig.SPRINT_SPEED else GameConfig.WALK_SPEED
	end
end

UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		sprinting = true
		applySpeed()
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
		sprinting = false
		applySpeed()
	end
end)

player.CharacterAdded:Connect(function()
	task.wait(0.3)
	applySpeed()
end)

-- Remote listeners: every one only renders server-authoritative state.
TimerTick.OnClientEvent:Connect(function(secondsLeft: number)
	timeLeft = secondsLeft
	refreshTopBar()
end)

CoinCollected.OnClientEvent:Connect(function(newTotal: number)
	coins = newTotal
	refreshTopBar()
	pulseCoins()
	showToast("🪙 Coin collected! +" .. "1", GameConfig.HUD_ACCENT)
end)

CheckpointReached.OnClientEvent:Connect(function(stage: number, stageName: string)
	currentStage = stage
	refreshTopBar()
	showToast(string.format("🏁 Stage %d clear — %s!", stage, stageName), GameConfig.HUD_ACCENT)
end)

HazardHit.OnClientEvent:Connect(function()
	showToast("💥 Spinner hit! Back to your checkpoint.", GameConfig.HUD_DANGER)
	local tweenInfo = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local flashTween = TweenService:Create(hazardFlash, tweenInfo, { BackgroundTransparency = 0.55 })
	flashTween:Play()
	flashTween.Completed:Connect(function()
		TweenService:Create(hazardFlash, tweenInfo, { BackgroundTransparency = 1 }):Play()
	end)
end)

PlayerWon.OnClientEvent:Connect(function(secondsLeft: number, totalCoins: number)
	won = true
	coins = totalCoins
	refreshTopBar()
	showEndScreen(
		"🏆 YOU REACHED THE SUMMIT!",
		string.format("Time to spare: %s  •  Coins: %d (incl. +%d win bonus)\nPersonal best height: %dm", formatTime(secondsLeft), totalCoins, GameConfig.WIN_BONUS_COINS, personalBest)
	)
end)

RoundOver.OnClientEvent:Connect(function(winners: { string })
	if won then
		return
	end
	local winnerText = if #winners > 0 then "Winners: " .. table.concat(winners, ", ") else "Nobody reached the summit."
	showEndScreen(
		"⏱ TIME'S UP!",
		string.format("You reached %dm on stage %d with %d coins.\nPersonal best height: %dm\n%s\nA new round starts in a moment — climb again!", maxHeight, math.max(currentStage, 1), coins, personalBest, winnerText)
	)
end)

-- A new session personal best: celebrate it, and remember it for the end screens.
PersonalBest.OnClientEvent:Connect(function(newBest: number)
	personalBest = newBest
	showToast(string.format("🌟 New personal best: %dm!", newBest), GameConfig.HUD_ACCENT)
end)

LeaderboardUpdate.OnClientEvent:Connect(function(top: { { name: string, height: number, coins: number, won: boolean } })
	for rank = 1, 5 do
		local row = leaderboardRows["rank" .. rank]
		if row then
			local entry = top[rank]
			if entry then
				local crown = if entry.won then " 👑" else ""
				row.Text = string.format("%d. %s — %dm · %d%s", rank, entry.name, entry.height, entry.coins, crown)
			else
				row.Text = string.format("%d. —", rank)
			end
		end
	end
end)

-- Buttons: Play dismisses the start screen; Climb Again asks the server
-- to reset this player and hides the end screen.
startScreen.playButton.MouseButton1Click:Connect(function()
	startScreen.frame.Visible = false
	showToast("Climb! Reach the golden summit before time runs out.", GameConfig.HUD_TEXT)
end)

endScreen.playAgainButton.MouseButton1Click:Connect(function()
	coins = 0
	maxHeight = 0
	currentStage = 0
	won = false
	refreshTopBar()
	hideEndScreen()
	PlayAgain:FireServer()
end)

-- Height readout: track the local character's height for the HUD between
-- server updates (the server's leaderstats value is authoritative).
task.spawn(function()
	while true do
		task.wait(0.5)
		local character = player.Character
		if character then
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local height = math.max(0, math.floor(root.Position.Y))
				if height > maxHeight then
					maxHeight = height
					refreshTopBar()
				end
			end
		end
	end
end)

refreshTopBar()
