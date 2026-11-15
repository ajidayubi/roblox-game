--!strict
-- GameConfig: the single source of truth for Tower Climb's tuning.
-- Shared by the server (world building, rules) and the client (HUD labels).
-- Every number here is mirrored by the screenshots: 5 stages, 6 platforms
-- per stage, 3 coins per stage, moving platforms from stage 2, spinner
-- hazards from stage 3 and vanishing platforms from stage 4.

local GameConfig = {}

GameConfig.GAME_NAME = "Tower Climb"
GameConfig.GAME_TAGLINE = "Climb the tower. Grab the coins. Beat the clock."

-- Round rules
GameConfig.ROUND_TIME_SECONDS = 180
GameConfig.STAGE_COUNT = 5
GameConfig.PLATFORMS_PER_STAGE = 6
GameConfig.COINS_PER_STAGE = 3
GameConfig.WIN_BONUS_COINS = 10

-- Movement
GameConfig.WALK_SPEED = 16
GameConfig.SPRINT_SPEED = 26
GameConfig.JUMP_POWER = 50

-- Stage palette (one colour per stage, used for platforms, checkpoint pads and HUD)
GameConfig.STAGE_COLORS = {
	Color3.fromRGB(45, 190, 170), -- Stage 1: teal
	Color3.fromRGB(245, 130, 40), -- Stage 2: orange
	Color3.fromRGB(155, 90, 230), -- Stage 3: purple
	Color3.fromRGB(90, 200, 80), -- Stage 4: green
	Color3.fromRGB(240, 200, 40), -- Stage 5: gold
}

GameConfig.STAGE_NAMES = {
	"Meadow Steps",
	"Ember Ledge",
	"Violet Spin",
	"Ghost Walk",
	"Golden Summit",
}

-- Geometry of one stage. Platforms zig-zag upward; later stages are
-- narrower with wider gaps, so the climb gets harder as you rise.
-- stageHeight: height of the stage's checkpoint pad above the base.
-- platformSize: size of a normal platform in this stage.
-- gapX / gapZ: centre-to-centre step between consecutive platforms.
GameConfig.STAGE_LAYOUT = {
	{ stageHeight = 30, platformSize = 9, gapX = 10, gapZ = 8 },
	{ stageHeight = 60, platformSize = 8, gapX = 11, gapZ = 9 },
	{ stageHeight = 90, platformSize = 7, gapX = 12, gapZ = 9 },
	{ stageHeight = 120, platformSize = 7, gapX = 12, gapZ = 10 },
	{ stageHeight = 150, platformSize = 6, gapX = 13, gapZ = 10 },
}

-- Which platform indices (1-based, within a stage) carry each mechanic.
GameConfig.MOVING_PLATFORM_INDICES = { 3, 5 }
GameConfig.SPINNER_PLATFORM_INDEX = 4
GameConfig.VANISHING_PLATFORM_INDICES = { 2, 6 }
GameConfig.COIN_PLATFORM_INDICES = { 2, 4, 6 }

-- Mechanics tuning
GameConfig.MOVE_DISTANCE = 5 -- studs a moving platform slides, each way
GameConfig.MOVE_TIME = 2.5 -- seconds per slide
GameConfig.SPIN_SPEED_DEGREES = 75 -- spinner rotation speed
GameConfig.VANISH_VISIBLE_SECONDS = 3
GameConfig.VANISH_HIDDEN_SECONDS = 2
GameConfig.COIN_SPIN_SPEED = 90 -- degrees per second
GameConfig.HAZARD_COOLDOWN_SECONDS = 1.5

-- HUD palette
GameConfig.HUD_BACKGROUND = Color3.fromRGB(20, 24, 38)
GameConfig.HUD_ACCENT = Color3.fromRGB(255, 210, 63)
GameConfig.HUD_TEXT = Color3.fromRGB(255, 255, 255)
GameConfig.HUD_DANGER = Color3.fromRGB(255, 80, 70)

return GameConfig
