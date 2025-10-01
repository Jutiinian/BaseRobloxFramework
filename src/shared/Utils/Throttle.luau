-- || Variables || --
local clock = os.clock

--[[
    Returns the function passed as a throttled function
    - Once ran, will wait provided number of seconds before able to run again 
]]
local function throttle<F>(func: F, seconds: number): F
	local lastCalled = 0
	local callNumber = 0

	return (
		function(...: any): any
			callNumber += 1
			local currentCallNumber = callNumber

			if clock() - lastCalled < seconds then
				task.wait(seconds - (clock() - lastCalled))

				if callNumber ~= currentCallNumber then
					return
				end
			end

			lastCalled = clock()
			return (func :: any)(...)
		end
	) :: any
end

return throttle
