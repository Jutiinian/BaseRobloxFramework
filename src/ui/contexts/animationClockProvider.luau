--!strict

-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- || Dependencies || --
local Janitor = require(ReplicatedStorage.Packages.janitor)
local React = require(ReplicatedStorage.Packages.react)
local getDependencies = require(ReplicatedStorage.UI.utils.getDependencies)

-- || Types || --
export type AnimationClockControls = {
	start: () -> (),
	stop: () -> (),
	reset: () -> (),
	isRunning: () -> boolean,
}

type AnimationClockProviderProps = {
	autoStart: boolean?,
	children: React.ReactNode?,
}

type ClockData = {
	binding: React.Binding<number>,
	setValue: (number) -> (),
	lastStep: number,
	startTime: number,
	elapsedAtPause: number?,
	dependentCount: number,
}

type ClockManager = {
	clocks: { [number]: ClockData },
	isRunning: boolean,
	janitor: Janitor.Janitor,
}

-- || Constants || --
local DEFAULT_STEP_TIME = 1 / 60
local CLEANUP_DELAY = 0.5

-- || Context || --
local AnimationClockManagerContext = React.createContext(nil :: ClockManager?)
local AnimationClockControlsContext = React.createContext(nil :: AnimationClockControls?)

-- || Provider || --
local function AnimationClockProvider(props: AnimationClockProviderProps)
	local autoStart = if props.autoStart ~= nil then props.autoStart else true

	local manager = React.useMemo(function(): ClockManager
		return {
			clocks = {},
			isRunning = false,
			janitor = Janitor.new(),
			totalDependents = 0,
		}
	end, {})

	local startAllClocks = React.useCallback(function()
		if manager.isRunning then
			return
		end

		manager.isRunning = true
		local now = os.clock()

		-- Resume all clocks from their paused state
		for _, clockData in manager.clocks do
			if clockData.elapsedAtPause then
				clockData.startTime = now - clockData.elapsedAtPause
				clockData.elapsedAtPause = nil
			end
		end

		manager.janitor:Add(
			RunService.Heartbeat:Connect(function()
				local currentTime = os.clock()

				for stepTime, clockData in manager.clocks do
					if clockData.dependentCount <= 0 then
						continue
					end

					if currentTime - clockData.lastStep >= stepTime then
						clockData.lastStep = currentTime
						local elapsed = currentTime - clockData.startTime
						clockData.setValue(elapsed)
					end
				end
			end),
			"Disconnect",
			"HeartbeatConnection"
		)
	end, { manager })

	local stopAllClocks = React.useCallback(function()
		if not manager.isRunning then
			return
		end

		manager.isRunning = false
		local now = os.clock()

		-- Store elapsed time for each clock
		for _, clockData in manager.clocks do
			if not clockData.elapsedAtPause then
				clockData.elapsedAtPause = now - clockData.startTime
			end
		end

		manager.janitor:Remove("HeartbeatConnection")
	end, { manager })

	local resetAllClocks = React.useCallback(function()
		local now = os.clock()
		for _, clockData in manager.clocks do
			clockData.startTime = now
			clockData.elapsedAtPause = nil
			clockData.lastStep = now
			clockData.setValue(0)
		end
	end, { manager })

	local isRunning = React.useCallback(function()
		return manager.isRunning
	end, { manager })

	React.useEffect(function()
		if autoStart then
			startAllClocks()
		end

		return function()
			manager.janitor:Destroy()
		end
	end, getDependencies(autoStart, startAllClocks))

	local controls = React.useMemo(function()
		return {
			start = startAllClocks,
			stop = stopAllClocks,
			reset = resetAllClocks,
			isRunning = isRunning,
		}
	end, { startAllClocks, stopAllClocks, resetAllClocks, isRunning })

	return React.createElement(
		AnimationClockManagerContext.Provider,
		{ value = manager },
		React.createElement(AnimationClockControlsContext.Provider, { value = controls }, props.children)
	)
end

-- || Hooks || --

local function useAnimationClock(stepTime: number?): React.Binding<number>
	local manager = assert(React.useContext(AnimationClockManagerContext), "useAnimationClock must be used within AnimationClockProvider")
	local actualStepTime: number = if stepTime == nil then DEFAULT_STEP_TIME else stepTime

	-- Store the step time in a ref so cleanup always uses the correct value
	local stepTimeRef = React.useRef(actualStepTime)
	stepTimeRef.current = actualStepTime

	local clockData = React.useMemo(function()
		if not manager.clocks[actualStepTime] then
			local now = os.clock()
			local binding, setValue = React.createBinding(0)

			manager.clocks[actualStepTime] = {
				binding = binding,
				setValue = setValue,
				lastStep = now,
				startTime = now,
				elapsedAtPause = if manager.isRunning then nil else 0,
				dependentCount = 0,
			}
		end

		return manager.clocks[actualStepTime]
	end, getDependencies(manager, actualStepTime))

	React.useEffect(function()
		local currentStepTime = stepTimeRef.current
		local currentClockData = manager.clocks[currentStepTime]

		if not currentClockData then
			return
		end

		currentClockData.dependentCount += 1

		return function()
			local cleanupStepTime = currentStepTime
			local cleanupClockData = manager.clocks[cleanupStepTime]

			if not cleanupClockData then
				return
			end

			cleanupClockData.dependentCount -= 1

			if cleanupClockData.dependentCount <= 0 then
				task.delay(CLEANUP_DELAY, function()
					if cleanupClockData.dependentCount <= 0 then
						manager.clocks[cleanupStepTime] = nil
					end
				end)
			end
		end
	end, getDependencies(manager, clockData))

	return clockData.binding
end

local function useAnimationClockControls(): AnimationClockControls
	local controls =
		assert(React.useContext(AnimationClockControlsContext), "useAnimationClockControls must be used within AnimationClockProvider")

	return controls
end

return {
	Provider = AnimationClockProvider,
	useAnimationClock = useAnimationClock,
	useAnimationClockControls = useAnimationClockControls,
}
