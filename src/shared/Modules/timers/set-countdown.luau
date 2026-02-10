local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.promise)

type Promise = Promise.Promise

local function setCountdown(
	callback: (timeLeft: number) -> (),
	countdown: number,
	interval: number?
): Promise
	return Promise.each(table.create(countdown, 0), function(_, index)
		callback(countdown - (index - 1))
		return Promise.delay(interval or 1)
	end)
end

return setCountdown
