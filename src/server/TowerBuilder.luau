--!strict
-- TowerBuilder: builds the whole Tower Climb world from GameConfig.
-- One module, one job: turn the stage layout table into Parts, coins,
-- hazards, checkpoints and the spawn-area leaderboard board. The server
-- calls TowerBuilder.build(world) once at startup; nothing here knows
-- about players, timers or scores.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local TowerBuilder = {}

local function newPart(name: string, size: Vector3, position: Vector3, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Position = position
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = true
	part.Locked = true
	return part
end

local function addSparkle(part: Part)
	local light = Instance.new("PointLight")
	light.Color = part.Color
	light.Brightness = 0.6
	light.Range = 10
	light.Parent = part
end

-- Builds one stage's platforms. Returns the checkpoint pad for the stage.
local function buildStage(world: Folder, stageIndex: number): Part
	local layout = GameConfig.STAGE_LAYOUT[stageIndex]
	local stageColor = GameConfig.STAGE_COLORS[stageIndex]
	local baseY = (stageIndex - 1) * 30
	local platformSize = layout.platformSize

	-- Zig-zag: platforms alternate left/right while stepping forward in Z,
	-- so every jump is a short diagonal hop up.
	for platformIndex = 1, GameConfig.PLATFORMS_PER_STAGE do
		local y = baseY + 6 + (platformIndex - 1) * 4
		local x = (platformIndex % 2 == 0) and layout.gapX or -layout.gapX
		local z = (platformIndex - 1) * layout.gapZ - 20 + (stageIndex - 1) * 4
		local pos = Vector3.new(x, y, z)
		local platform = newPart(
			string.format("Stage%d_Platform%d", stageIndex, platformIndex),
			Vector3.new(platformSize, 2, platformSize),
			pos,
			stageColor,
			Enum.Material.SmoothPlastic
		)
		platform.Parent = world

		-- Moving platforms (stage 2+): slide sideways on a loop.
		if stageIndex >= 2 and table.find(GameConfig.MOVING_PLATFORM_INDICES, platformIndex) then
			platform:SetAttribute("Moving", true)
			platform:SetAttribute("MoveDistance", GameConfig.MOVE_DISTANCE)
			platform:SetAttribute("MoveTime", GameConfig.MOVE_TIME)
			platform:SetAttribute("HomePosition", pos)
		end

		-- Vanishing platforms (stage 4+): fade out and back on a cycle.
		if stageIndex >= 4 and table.find(GameConfig.VANISHING_PLATFORM_INDICES, platformIndex) then
			platform:SetAttribute("Vanishing", true)
			platform:SetAttribute("VisibleSeconds", GameConfig.VANISH_VISIBLE_SECONDS)
			platform:SetAttribute("HiddenSeconds", GameConfig.VANISH_HIDDEN_SECONDS)
		end

		-- Spinner hazard (stage 3+): a rotating bar sweeping the platform.
		if stageIndex >= 3 and platformIndex == GameConfig.SPINNER_PLATFORM_INDEX then
			local spinner = newPart(
				string.format("Stage%d_Spinner", stageIndex),
				Vector3.new(platformSize + 4, 1, 1),
				pos + Vector3.new(0, 1.5, 0),
				Color3.fromRGB(220, 40, 40),
				Enum.Material.Neon
			)
			spinner:SetAttribute("Spinner", true)
			spinner:SetAttribute("SpinSpeed", GameConfig.SPIN_SPEED_DEGREES)
			spinner.Parent = world
			addSparkle(spinner)
		end

		-- Coins sit just above their platforms, spinning in place.
		if table.find(GameConfig.COIN_PLATFORM_INDICES, platformIndex) then
			local coin = Instance.new("Part")
			coin.Name = string.format("Stage%d_Coin%d", stageIndex, platformIndex)
			coin.Shape = Enum.PartType.Cylinder
			coin.Size = Vector3.new(1, 3, 3)
			coin.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) * CFrame.Angles(0, 0, math.rad(90))
			coin.Color = Color3.fromRGB(255, 210, 63)
			coin.Material = Enum.Material.Neon
			coin.Anchored = true
			coin.CanCollide = false
			coin.CanQuery = true
			coin:SetAttribute("Coin", true)
			coin:SetAttribute("CoinValue", 1)
			coin.Parent = world
			addSparkle(coin)
		end
	end

	-- Checkpoint pad: wide, glowing, ends the stage and saves the climber.
	-- stageHeight is the pad's absolute height above the base (see GameConfig).
	local checkpointY = layout.stageHeight
	local checkpoint = newPart(
		string.format("Stage%d_Checkpoint", stageIndex),
		Vector3.new(14, 1, 14),
		Vector3.new(0, checkpointY, 24),
		stageColor,
		Enum.Material.Neon
	)
	checkpoint:SetAttribute("Checkpoint", true)
	checkpoint:SetAttribute("Stage", stageIndex)
	checkpoint.Parent = world
	addSparkle(checkpoint)

	return checkpoint
end

local function buildSummit(world: Folder)
	local summitY = 156
	local pad = newPart(
		"SummitPad",
		Vector3.new(18, 2, 18),
		Vector3.new(0, summitY, 28),
		Color3.fromRGB(255, 215, 80),
		Enum.Material.Neon
	)
	pad:SetAttribute("Summit", true)
	pad.Parent = world
	addSparkle(pad)

	-- Flag pole and banner so the summit reads as the finish at a glance.
	local pole = newPart("SummitFlagPole", Vector3.new(0.6, 12, 0.6), Vector3.new(-7, summitY + 7, 22), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	pole.Parent = world
	local banner = newPart("SummitFlag", Vector3.new(6, 3.5, 0.4), Vector3.new(-3.6, summitY + 11, 22), Color3.fromRGB(255, 210, 63), Enum.Material.Fabric)
	banner.Parent = world

	-- The summit bonus coin, the richest single pickup in the game.
	local coin = Instance.new("Part")
	coin.Name = "SummitCoin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(1, 4, 4)
	coin.CFrame = CFrame.new(Vector3.new(5, summitY + 4, 32)) * CFrame.Angles(0, 0, math.rad(90))
	coin.Color = Color3.fromRGB(255, 210, 63)
	coin.Material = Enum.Material.Neon
	coin.Anchored = true
	coin.CanCollide = false
	coin:SetAttribute("Coin", true)
	coin:SetAttribute("CoinValue", 5)
	coin.Parent = world
	addSparkle(coin)
end

local function buildLeaderboardBoard(world: Folder)
	-- A standing board by the spawn pad; the server writes the top 5 into it.
	local board = newPart("LeaderboardBoard", Vector3.new(12, 8, 1), Vector3.new(-14, 6, -8), Color3.fromRGB(30, 34, 52), Enum.Material.SmoothPlastic)
	board.Parent = world

	local gui = Instance.new("SurfaceGui")
	gui.Name = "LeaderboardGui"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(600, 400)
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 60)
	title.BackgroundTransparency = 1
	title.Text = "🏆 TOP CLIMBERS"
	title.TextColor3 = GameConfig.HUD_ACCENT
	title.Font = Enum.Font.GothamBold
	title.TextScaled = true
	title.Parent = gui

	for rank = 1, 5 do
		local row = Instance.new("TextLabel")
		row.Name = "Rank" .. rank
		row.Size = UDim2.new(1, -20, 0, 60)
		row.Position = UDim2.new(0, 10, 0, 60 + (rank - 1) * 64)
		row.BackgroundTransparency = 1
		row.Text = string.format("%d. —", rank)
		row.TextColor3 = GameConfig.HUD_TEXT
		row.Font = Enum.Font.Gotham
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.Parent = gui
	end
end

function TowerBuilder.build(world: Folder)
	for stageIndex = 1, GameConfig.STAGE_COUNT do
		buildStage(world, stageIndex)
	end
	buildSummit(world)
	buildLeaderboardBoard(world)
end

return TowerBuilder
