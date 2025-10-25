--!strict

-- || Variables || --
local taskDelay = task.delay

-- || Public API || --
--[[
    Creates a simple rate-limiter closure.
    - Returns a function that enforces a maximum number of allowed calls within a time interval
    - If a key is provided, rate-limit is tracked per unique Key
        - Useful for per-player, per-instance, or per-action limits
    - If no Key is provided, a single shared counter is used (global limiting)
]]
local function RateLimit<T>(Limit: number, Interval: number)
	assert(Limit > 0, "Limit must be greater than 0")

	local CountMap = {} :: { [T]: number }
	local CountKeyless = 0

	return function(Key: T?)
		if Key then
			local Count = CountMap[Key]

			if Count == nil then
				Count = 0

				taskDelay(Interval, function()
					CountMap[Key] = nil
				end)
			end

			if Count == Limit then
				return false
			end

			CountMap[Key] = Count + 1
		else
			if CountKeyless == 0 then
				taskDelay(Interval, function()
					CountKeyless = 0
				end)
			end

			if CountKeyless == Limit then
				return false
			end

			CountKeyless = CountKeyless + 1
		end

		return true
	end
end

return RateLimit
