--!strict
-- GameServer: the authoritative brain of Tower Climb.
-- Owns the world (built once by TowerBuilder), the round timer, coin and
-- checkpoint collection, hazards, falls, wins and the leaderboard. The
-- client only ever renders state and asks to restart; every score, timer
-- and teleport decision is made here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local TowerBuilder = require(script.Parent:WaitForChild("TowerBuilder"))
local LeaderboardService = require(script.Parent:WaitForChild("LeaderboardService"))

-- World folder holding every tower part, coin and hazard.
local world = Instance.new("Folder")
world.Name = "TowerWorld"
world.Parent = Workspace
TowerBuilder.build(world)

-- Remotes: one folder, one event per message, created by the server so the
-- client only ever listens (or fires PlayAgain to ask for a restart).
local remotes = Instance.new("Folder")
remotes.Name = "TowerRemotes"
remotes.Parent = ReplicatedStorage

local function makeRemote(name: string): RemoteEvent
	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = remotes
	return remote
end

local TimerTick = makeRemote("TimerTick") -- (secondsLeft)
local CoinCollected = makeRemote("CoinCollected") -- (newCoinTotal)
local CheckpointReached = makeRemote("CheckpointReached") -- (stage, stageName)
local HazardHit = makeRemote("HazardHit") -- ()
local PlayerWon = makeRemote("PlayerWon") -- (secondsLeft, coins)
local RoundOver = makeRemote("RoundOver") -- (winners: {string})
local LeaderboardUpdate = makeRemote("LeaderboardUpdate") -- (top: {ClimberEntry})
local PersonalBest = makeRemote("PersonalBest") -- (newBestHeight)
local PlayAgain = makeRemote("PlayAgain") -- client -> server, no payload

type PlayerState = {
	coins: number,
	maxHeight: number,
	personalBest: number, -- best height this session, kept across rounds
	stage: number,
	checkpoint: CFrame,
	won: boolean,
	winTimeLeft: number,
	lastHazardHit: number,
	leaderstatsCoins: IntValue,
	leaderstatsHeight: IntValue,
}

local states: { [Player]: PlayerState } = {}
local SPAWN_CFRAME = CFrame.new(0, 4, 0)
local FALL_Y = -12
local roundTimeLeft = GameConfig.ROUND_TIME_SECONDS
local roundActive = false
local coinDebounce: { [Instance]: { [Player]: number } } = {}

local function getState(player: Player): PlayerState?
	return states[player]
end

local function teleportToCheckpoint(player: Player)
	local state = getState(player)
	local character = player.Character
	if state == nil or character == nil then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		root.CFrame = state.checkpoint + Vector3.new(0, 3, 0)
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function broadcastLeaderboard()
	local top = LeaderboardService.getTop(5)
	LeaderboardUpdate:FireAllClients(top)
	-- The standing board by the spawn pad shows the same top five.
	local board = world:FindFirstChild("LeaderboardBoard")
	if board then
		local gui = board:FindFirstChild("LeaderboardGui")
		if gui then
			for rank = 1, 5 do
				local row = gui:FindFirstChild("Rank" .. rank)
				if row and row:IsA("TextLabel") then
					local entry = top[rank]
					if entry then
						local crown = entry.won and " 👑" or ""
						row.Text = string.format("%d. %s — %dm · %d coins%s", rank, entry.name, entry.height, entry.coins, crown)
					else
						row.Text = string.format("%d. —", rank)
					end
				end
			end
		end
	end
end

local function resetPlayerForRound(player: Player)
	local state = getState(player)
	if state == nil then
		return
	end
	state.coins = 0
	state.maxHeight = 0
	state.stage = 0
	state.checkpoint = SPAWN_CFRAME
	state.won = false
	state.winTimeLeft = 0
	state.leaderstatsCoins.Value = 0
	state.leaderstatsHeight.Value = 0
	LeaderboardService.clearPlayer(player)
end

local function resetCoins()
	for _, descendant in world:GetDescendants() do
		if descendant:GetAttribute("Coin") == true then
			descendant.Transparency = 0
			descendant.CanQuery = true
		end
	end
	table.clear(coinDebounce)
end

local function startRound()
	resetCoins()
	for _, player in Players:GetPlayers() do
		resetPlayerForRound(player)
		teleportToCheckpoint(player)
	end
	roundTimeLeft = GameConfig.ROUND_TIME_SECONDS
	roundActive = true
	broadcastLeaderboard()
end

local function endRound()
	roundActive = false
	local winners: { string } = {}
	for player, state in states do
		if state.won then
			table.insert(winners, player.Name)
		end
	end
	RoundOver:FireAllClients(winners)
	task.delay(6, function()
		if not roundActive then
			startRound()
		end
	end)
end

local function onPlayerAdded(player: Player)
	-- leaderstats: the built-in Roblox leaderboard shows Coins and Height.
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local coinsValue = Instance.new("IntValue")
	coinsValue.Name = "Coins"
	coinsValue.Value = 0
	coinsValue.Parent = leaderstats
	local heightValue = Instance.new("IntValue")
	heightValue.Name = "Height"
	heightValue.Value = 0
	heightValue.Parent = leaderstats

	states[player] = {
		coins = 0,
		maxHeight = 0,
		personalBest = 0,
		stage = 0,
		checkpoint = SPAWN_CFRAME,
		won = false,
		winTimeLeft = 0,
		lastHazardHit = 0,
		leaderstatsCoins = coinsValue,
		leaderstatsHeight = heightValue,
	}
	player.CharacterAdded:Connect(function(character: Model)
		-- Respawn at the saved checkpoint, not at the base, so a fall or a
		-- hazard costs the current stage's progress, never the whole climb.
		task.wait(0.2)
		teleportToCheckpoint(player)
		local humanoid = character:WaitForChild("Humanoid")
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.WalkSpeed = GameConfig.WALK_SPEED
			humanoid.JumpPower = GameConfig.JUMP_POWER
		end
	end)
	if not roundActive and #Players:GetPlayers() >= 1 then
		startRound()
	end
	broadcastLeaderboard()
end

local function onPlayerRemoving(player: Player)
	states[player] = nil
	LeaderboardService.clearPlayer(player)
	broadcastLeaderboard()
end

-- Coin pickup: server-side Touched, debounced per player per coin, so the
-- score can never be faked from the client.
local function watchCoin(coin: BasePart)
	local value = coin:GetAttribute("CoinValue")
	local coinValue = if typeof(value) == "number" then value else 1
	coin.Touched:Connect(function(hit: BasePart)
		local character = hit.Parent
		if character == nil then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if player == nil then
			return
		end
		local state = getState(player)
		if state == nil or state.won or not roundActive then
			return
		end
		local now = os.clock()
		local perCoin = coinDebounce[coin]
		if perCoin == nil then
			perCoin = {}
			coinDebounce[coin] = perCoin
		end
		if perCoin[player] and now - perCoin[player] < 1 then
			return
		end
		perCoin[player] = now
		if coin.Transparency >= 1 then
			return
		end
		coin.Transparency = 1
		coin.CanQuery = false
		state.coins += coinValue
		state.leaderstatsCoins.Value = state.coins
		CoinCollected:FireClient(player, state.coins)
		LeaderboardService.record(player, state.maxHeight, state.coins, state.won)
		broadcastLeaderboard()
	end)
end

-- Checkpoint pads and the summit pad: standing on one saves progress.
local function watchPad(pad: BasePart)
	local isSummit = pad:GetAttribute("Summit") == true
	local stage = pad:GetAttribute("Stage")
	local stageNumber = if typeof(stage) == "number" then stage else 0
	pad.Touched:Connect(function(hit: BasePart)
		local character = hit.Parent
		if character == nil then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if player == nil then
			return
		end
		local state = getState(player)
		if state == nil or not roundActive then
			return
		end
		if isSummit then
			if state.won then
				return
			end
			state.won = true
			state.winTimeLeft = roundTimeLeft
			state.coins += GameConfig.WIN_BONUS_COINS
			state.leaderstatsCoins.Value = state.coins
			LeaderboardService.record(player, state.maxHeight, state.coins, true)
			broadcastLeaderboard()
			PlayerWon:FireClient(player, state.winTimeLeft, state.coins)
			return
		end
		if stageNumber > state.stage then
			state.stage = stageNumber
			state.checkpoint = pad.CFrame
			CheckpointReached:FireClient(player, stageNumber, GameConfig.STAGE_NAMES[stageNumber])
			LeaderboardService.record(player, state.maxHeight, state.coins, state.won)
			broadcastLeaderboard()
		end
	end)
end

-- Spinner hazards: touching the red bar sends the climber back to their
-- last checkpoint with a short cooldown so one touch is one penalty.
local function watchSpinner(spinner: BasePart)
	spinner.Touched:Connect(function(hit: BasePart)
		local character = hit.Parent
		if character == nil then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if player == nil then
			return
		end
		local state = getState(player)
		if state == nil or state.won or not roundActive then
			return
		end
		local now = os.clock()
		if now - state.lastHazardHit < GameConfig.HAZARD_COOLDOWN_SECONDS then
			return
		end
		state.lastHazardHit = now
		HazardHit:FireClient(player)
		teleportToCheckpoint(player)
	end)
end

-- Moving platforms slide on a looping tween; spinners rotate and coins
-- spin on the heartbeat; vanishing platforms cycle visibility.
local function animateWorld()
	for _, descendant in world:GetDescendants() do
		if descendant:GetAttribute("Moving") == true and descendant:IsA("BasePart") then
			local home = descendant:GetAttribute("HomePosition")
			local distance = descendant:GetAttribute("MoveDistance")
			local moveTime = descendant:GetAttribute("MoveTime")
			if typeof(home) == "Vector3" and typeof(distance) == "number" and typeof(moveTime) == "number" then
				local goal = home + Vector3.new(distance, 0, 0)
				local tweenInfo = TweenInfo.new(moveTime, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
				local tween = TweenService:Create(descendant, tweenInfo, { Position = goal })
				tween:Play()
			end
		end
	end

	RunService.Heartbeat:Connect(function(deltaTime: number)
		for _, descendant in world:GetDescendants() do
			if descendant:GetAttribute("Spinner") == true and descendant:IsA("BasePart") then
				local speed = descendant:GetAttribute("SpinSpeed")
				local degrees = if typeof(speed) == "number" then speed else GameConfig.SPIN_SPEED_DEGREES
				descendant.CFrame = descendant.CFrame * CFrame.Angles(0, math.rad(degrees * deltaTime), 0)
			elseif descendant:GetAttribute("Coin") == true and descendant:IsA("BasePart") then
				descendant.CFrame = descendant.CFrame * CFrame.Angles(0, math.rad(GameConfig.COIN_SPIN_SPEED * deltaTime), 0)
			end
		end
	end)

	-- Vanishing platforms: visible, then gone, then visible again.
	for _, descendant in world:GetDescendants() do
		if descendant:GetAttribute("Vanishing") == true and descendant:IsA("BasePart") then
			local platform = descendant
			task.spawn(function()
				while platform.Parent ~= nil do
					task.wait(GameConfig.VANISH_VISIBLE_SECONDS)
					platform.Transparency = 0.85
					platform.CanCollide = false
					task.wait(GameConfig.VANISH_HIDDEN_SECONDS)
					platform.Transparency = 0
					platform.CanCollide = true
				end
			end)
		end
	end
end

-- Per-second loop: the round timer, the fall check and best-height tracking.
local function startLoops()
	task.spawn(function()
		while true do
			task.wait(1)
			if roundActive then
				roundTimeLeft -= 1
				TimerTick:FireAllClients(math.max(roundTimeLeft, 0))
				if roundTimeLeft <= 0 then
					endRound()
				end
			end
		end
	end)

	RunService.Heartbeat:Connect(function()
		for player, state in states do
			local character = player.Character
			if character == nil then
				continue
			end
			local root = character:FindFirstChild("HumanoidRootPart")
			if root == nil or not root:IsA("BasePart") then
				continue
			end
			-- Best height, in whole metres above the base. Beating the
			-- session personal best earns a toast on the client.
			local height = math.max(0, math.floor(root.Position.Y))
			if height > state.maxHeight then
				state.maxHeight = height
				state.leaderstatsHeight.Value = height
				if height > state.personalBest then
					state.personalBest = height
					PersonalBest:FireClient(player, height)
				end
			end
			-- Fell off the tower: back to the last checkpoint.
			if root.Position.Y < FALL_Y then
				teleportToCheckpoint(player)
			end
		end
	end)
end

-- Wire up every interactive part the builder made.
for _, descendant in world:GetDescendants() do
	if descendant:GetAttribute("Coin") == true and descendant:IsA("BasePart") then
		watchCoin(descendant)
	elseif (descendant:GetAttribute("Checkpoint") == true or descendant:GetAttribute("Summit") == true) and descendant:IsA("BasePart") then
		watchPad(descendant)
	elseif descendant:GetAttribute("Spinner") == true and descendant:IsA("BasePart") then
		watchSpinner(descendant)
	end
end

-- Play Again: a client asks, the server resets that one player and sends
-- them back to the base to climb again.
PlayAgain.OnServerEvent:Connect(function(player: Player)
	local state = getState(player)
	if state == nil then
		return
	end
	state.coins = 0
	state.maxHeight = 0
	state.stage = 0
	state.checkpoint = SPAWN_CFRAME
	state.won = false
	state.winTimeLeft = 0
	state.leaderstatsCoins.Value = 0
	state.leaderstatsHeight.Value = 0
	teleportToCheckpoint(player)
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

animateWorld()
startLoops()
startRound()
