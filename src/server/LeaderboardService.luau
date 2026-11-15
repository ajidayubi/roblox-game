--!strict
-- LeaderboardService: the single place that owns climb rankings.
-- In-memory only (no DataStore calls, so nothing can fail on a service
-- error): each player's best height and coins are recorded, and the top
-- five by height, then coins, are served to the board and the HUD.

local LeaderboardService = {}

export type ClimberEntry = {
	name: string,
	height: number,
	coins: number,
	won: boolean,
}

local bestByPlayer: { [number]: ClimberEntry } = {}

function LeaderboardService.record(player: Player, height: number, coins: number, won: boolean)
	local userId = player.UserId
	local previous = bestByPlayer[userId]
	if previous == nil then
		bestByPlayer[userId] = { name = player.Name, height = height, coins = coins, won = won }
		return
	end
	previous.name = player.Name
	previous.height = math.max(previous.height, height)
	previous.coins = math.max(previous.coins, coins)
	previous.won = previous.won or won
end

function LeaderboardService.getTop(count: number): { ClimberEntry }
	local entries: { ClimberEntry } = {}
	for _, entry in bestByPlayer do
		table.insert(entries, entry)
	end
	table.sort(entries, function(a: ClimberEntry, b: ClimberEntry): boolean
		if a.height ~= b.height then
			return a.height > b.height
		end
		return a.coins > b.coins
	end)
	local top: { ClimberEntry } = {}
	for i = 1, math.min(count, #entries) do
		table.insert(top, entries[i])
	end
	return top
end

function LeaderboardService.clearPlayer(player: Player)
	bestByPlayer[player.UserId] = nil
end

return LeaderboardService
