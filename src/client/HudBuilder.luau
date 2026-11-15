--!strict
-- HudBuilder: builds every ScreenGui element Tower Climb shows the player.
-- One module, one job: layout and styling only. TowerClient owns the
-- behaviour (wiring buttons, listening to remotes, updating the numbers).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local HudBuilder = {}

local function label(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, textSize: number, color: Color3): TextLabel
	local element = Instance.new("TextLabel")
	element.Name = name
	element.Size = size
	element.Position = position
	element.BackgroundTransparency = 1
	element.Text = text
	element.TextColor3 = color
	element.Font = Enum.Font.GothamBold
	element.TextSize = textSize
	element.TextScaled = false
	element.Parent = parent
	return element
end

local function panel(parent: Instance, name: string, size: UDim2, position: UDim2): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = GameConfig.HUD_BACKGROUND
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	frame.Parent = parent
	return frame
end

-- Top-centre stat bar: time, coins, height and stage. Kept clear of the
-- top-left corner, where Roblox draws its own menu buttons.
function HudBuilder.buildTopBar(gui: ScreenGui): { [string]: TextLabel }
	local bar = panel(gui, "TopBar", UDim2.new(0, 520, 0, 54), UDim2.new(0.5, -260, 0, 12))
	local timeLabel = label(bar, "TimeLabel", "⏱ 3:00", UDim2.new(0, 120, 1, 0), UDim2.new(0, 12, 0, 0), 24, GameConfig.HUD_TEXT)
	local coinsLabel = label(bar, "CoinsLabel", "🪙 0", UDim2.new(0, 120, 1, 0), UDim2.new(0, 142, 0, 0), 24, GameConfig.HUD_ACCENT)
	local heightLabel = label(bar, "HeightLabel", "📏 0m", UDim2.new(0, 120, 1, 0), UDim2.new(0, 272, 0, 0), 24, GameConfig.HUD_TEXT)
	local stageLabel = label(bar, "StageLabel", "Stage 1/5", UDim2.new(0, 120, 1, 0), UDim2.new(0, 392, 0, 0), 22, GameConfig.HUD_ACCENT)
	return {
		time = timeLabel,
		coins = coinsLabel,
		height = heightLabel,
		stage = stageLabel,
	}
end

-- Right-side mini leaderboard: the top five climbers, live.
function HudBuilder.buildLeaderboardPanel(gui: ScreenGui): { [string]: TextLabel }
	local board = panel(gui, "LeaderboardPanel", UDim2.new(0, 220, 0, 210), UDim2.new(1, -236, 0, 84))
	label(board, "Title", "🏆 TOP CLIMBERS", UDim2.new(1, 0, 0, 34), UDim2.new(0, 0, 0, 6), 18, GameConfig.HUD_ACCENT)
	local rows: { [string]: TextLabel } = {}
	for rank = 1, 5 do
		rows["rank" .. rank] = label(
			board,
			"Rank" .. rank,
			string.format("%d. —", rank),
			UDim2.new(1, -16, 0, 28),
			UDim2.new(0, 8, 0, 40 + (rank - 1) * 32),
			17,
			GameConfig.HUD_TEXT
		)
		rows["rank" .. rank].TextXAlignment = Enum.TextXAlignment.Left
		rows["rank" .. rank].Font = Enum.Font.Gotham
	end
	return rows
end

-- Centre toast: short feedback messages ("Checkpoint!", "Coin +1!").
function HudBuilder.buildToast(gui: ScreenGui): TextLabel
	local toast = label(gui, "Toast", "", UDim2.new(0, 420, 0, 44), UDim2.new(0.5, -210, 0, 84), 26, GameConfig.HUD_ACCENT)
	toast.TextStrokeTransparency = 0.4
	toast.Visible = false
	return toast
end

-- Start screen: title, how to play, and the Play button.
function HudBuilder.buildStartScreen(gui: ScreenGui): { frame: Frame, playButton: TextButton }
	local frame = Instance.new("Frame")
	frame.Name = "StartScreen"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(12, 16, 30)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local title = label(frame, "Title", "🗼 TOWER CLIMB", UDim2.new(0, 560, 0, 80), UDim2.new(0.5, -280, 0, 110), 56, GameConfig.HUD_ACCENT)
	title.TextStrokeTransparency = 0.2
	label(frame, "Tagline", GameConfig.GAME_TAGLINE, UDim2.new(0, 560, 0, 34), UDim2.new(0.5, -280, 0, 196), 22, GameConfig.HUD_TEXT)
	label(
		frame,
		"Instructions",
		"Climb 5 stages to the Golden Summit before the 3:00 timer ends.\n"
			.. "🪙 Collect coins  •  🟥 Dodge the red spinners  •  🏁 Touch a glowing pad to save a checkpoint\n"
			.. "Fall and you restart from your last checkpoint — never from the bottom.\n"
			.. "Move: WASD / arrows  •  Jump: Space  •  Sprint: hold Shift",
		UDim2.new(0, 620, 0, 130),
		UDim2.new(0.5, -310, 0, 250),
		20,
		GameConfig.HUD_TEXT
	)

	local playButton = Instance.new("TextButton")
	playButton.Name = "PlayButton"
	playButton.Size = UDim2.new(0, 240, 0, 64)
	playButton.Position = UDim2.new(0.5, -120, 0, 410)
	playButton.BackgroundColor3 = GameConfig.HUD_ACCENT
	playButton.Text = "▶  PLAY"
	playButton.TextColor3 = Color3.fromRGB(20, 24, 38)
	playButton.Font = Enum.Font.GothamBold
	playButton.TextSize = 28
	playButton.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = playButton

	return { frame = frame, playButton = playButton }
end

-- End screen: shown on a win, a timeout, or after Play Again is pressed.
function HudBuilder.buildEndScreen(gui: ScreenGui): { frame: Frame, title: TextLabel, stats: TextLabel, playAgainButton: TextButton }
	local frame = Instance.new("Frame")
	frame.Name = "EndScreen"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(12, 16, 30)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui

	local title = label(frame, "Title", "🏆 YOU REACHED THE SUMMIT!", UDim2.new(0, 640, 0, 72), UDim2.new(0.5, -320, 0, 130), 40, GameConfig.HUD_ACCENT)
	local stats = label(frame, "Stats", "", UDim2.new(0, 640, 0, 100), UDim2.new(0.5, -320, 0, 220), 24, GameConfig.HUD_TEXT)

	local playAgainButton = Instance.new("TextButton")
	playAgainButton.Name = "PlayAgainButton"
	playAgainButton.Size = UDim2.new(0, 260, 0, 64)
	playAgainButton.Position = UDim2.new(0.5, -130, 0, 350)
	playAgainButton.BackgroundColor3 = GameConfig.HUD_ACCENT
	playAgainButton.Text = "↻  CLIMB AGAIN"
	playAgainButton.TextColor3 = Color3.fromRGB(20, 24, 38)
	playAgainButton.Font = Enum.Font.GothamBold
	playAgainButton.TextSize = 26
	playAgainButton.Parent = frame
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = playAgainButton

	return { frame = frame, title = title, stats = stats, playAgainButton = playAgainButton }
end

-- Full-screen red flash shown when a spinner knocks the player back.
function HudBuilder.buildHazardFlash(gui: ScreenGui): Frame
	local flash = Instance.new("Frame")
	flash.Name = "HazardFlash"
	flash.Size = UDim2.new(1, 0, 1, 0)
	flash.BackgroundColor3 = Color3.fromRGB(255, 40, 30)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Parent = gui
	return flash
end

return HudBuilder
