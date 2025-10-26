-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

-- || Ensure Client Only
if not RunService:IsClient() then
	return {} :: InputService
end

-- || Dependencies || --
local Signal = require(ReplicatedStorage.Packages.Signal)

-- || Variables || --
type input = Enum.KeyCode | Enum.UserInputType
type actionData = {
	context: string,
	keys: { input },
}

-- || Public API || --
local InputService = {
	_actions = {} :: { [string]: actionData },
	_keyActions = {} :: { [input]: { string } },

	_signals = {
		ActionTriggered = {} :: { [string]: Signal.Signal<("Began" | "Ended", input)> },
		ActionBegan = {} :: { [string]: Signal.Signal<input> },
		ActionEnded = {} :: { [string]: Signal.Signal<input> },
	},

	_contexts = {
		Gameplay = true,
	} :: { [string]: boolean },

	_autoCleanThread = nil :: thread?,
}

--[[
	Initializes the InputService by connecting user input events and starting the auto-clean thread.
	- Listens to UserInputService.InputBegan and InputEnded.
	- Ignores inputs that are already processed by other systems.
	- Spawns a background task to periodically clear unused signals every 30 seconds.
]]
function InputService.Init(self: InputService)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end

		self:_inputBegan(input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode or input.UserInputType)
	end)

	UserInputService.InputEnded:Connect(function(input, processed)
		if processed then
			return
		end

		self:_inputEnded(input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode or input.UserInputType)
	end)

	self._autoCleanThread = task.spawn(function()
		while true do
			task.wait(30)
			self:_clearTable()
		end
	end)
end

--[[
	Binds one or more keys to a specific action.
	- actionName: string representing the action to trigger.
	- keys: table of Enum.KeyCode or Enum.UserInputType to bind.
	- context: optional string; defaults to "Gameplay". Action will only trigger when this context is enabled.
	- Throws an error if the action already exists.
	- Creates the action internally and binds each key to it.
]]
function InputService.BindAction(self: InputService, actionName: string, keys: { input }, context: string?)
	assert(self._actions[actionName] == nil, `InputService: {actionName} already exists`)

	context = context or "Gameplay"

	self:_validateContext(context :: string)
	self:_createAction(actionName, keys, context :: string)

	for _, key in ipairs(keys) do
		self:_bindActionToKey(actionName, key)
	end
end

function InputService.UnbindAction(self: InputService, actionName: string)
	if not self._actions[actionName] then
		return
	end

	local actionData = self._actions[actionName]

	for _, input in ipairs(actionData.keys) do
		local keyActions = self._keyActions[input]
		if not keyActions then
			continue
		end

		for i = #keyActions, 1, -1 do
			if keyActions[i] == actionName then
				table.remove(keyActions, i)
			end
		end
	end

	for _, signals in pairs(self._signals) do
		for action, signal in ipairs(signals) do
			if action ~= actionName then
				continue
			end

			signal:DisconnectAll()
			signal:Destroy()
			signals[action] = nil
		end
	end

	self._actions[actionName] = nil

	print(self._signals, self._keyActions, self._actions)
end

--[[
	Returns the Signal that fires when the specified action begins.
	- actionName: string name of the action.
	- The returned Signal passes the input that triggered the action.
	- Throws an error if the action does not exist.
	- Useful for subscribing to the "Began" phase of an action.
]]
function InputService.GetActionBeganSignal(self: InputService, actionName: string): Signal.Signal<input>
	assert(self._actions[actionName], `InputService: {actionName} does not exist`)
	return self:_retrieveSignal(actionName, "ActionBegan")
end

--[[
	Returns the Signal that fires when the specified action ends.
	- actionName: string name of the action.
	- The returned Signal passes the input that ended the action.
	- Throws an error if the action does not exist.
	- Useful for subscribing to the "Ended" phase of an action.
]]
function InputService.GetActionEndedSignal(self: InputService, actionName: string): Signal.Signal<input>
	assert(self._actions[actionName], `InputService: {actionName} does not exist`)
	return self:_retrieveSignal(actionName, "ActionEnded")
end

--[[
	Returns a unified Signal that fires whenever the specified action is triggered.
	- actionName: string name of the action.
	- The Signal passes two parameters: event type ("Began" or "Ended") and the input that triggered it.
	- Throws an error if the action does not exist.
	- Useful when you want a single subscription for both start and end events.
]]
function InputService.GetActionTriggered(self: InputService, actionName: string): Signal.Signal<("Began" | "Ended", input)>
	assert(self._actions[actionName], `InputService: {actionName} does not exist`)
	return self:_retrieveSignal(actionName, "ActionTriggered")
end

--[[
	Enables a specific input context.
	- context: string name of the context to enable.
	- Only actions bound to enabled contexts will trigger.
	- Does nothing if the context does not exist.
]]
function InputService.EnableContext(self: InputService, context: string)
	if self._contexts[context] == nil then
		return
	end

	self._contexts[context] = true
end

--[[
	Disables a specific input context.
	- context: string name of the context to disable.
	- Actions bound to a disabled context will not trigger until it is re-enabled.
	- Does nothing if the context does not exist.
]]
function InputService.DisableContext(self: InputService, context: string)
	if self._contexts[context] == nil then
		return
	end

	self._contexts[context] = false
end

-- Hidden functions
function InputService._createAction(self: InputService, actionName: string, keys: { input }, context: string)
	self._actions[actionName] = {
		keys = keys,
		context = context,
	}
end

function InputService._validateContext(self: InputService, context: string)
	if self._contexts[context] ~= nil then
		return
	end

	self._contexts[context] = true
end

function InputService._bindActionToKey(self: InputService, actionName: string, key: input)
	if not self._keyActions[key] then
		self._keyActions[key] = {}
	end

	table.insert(self._keyActions[key], actionName)
end

function InputService._inputBegan(self: InputService, key: input)
	if not self._keyActions[key] then
		return
	end

	for _, actionName in ipairs(self._keyActions[key]) do
		local actionData = self._actions[actionName]
		if not actionData or not self._contexts[actionData.context] then
			continue
		end

		self:_fireSignal(actionName, "ActionBegan", key)
		self:_fireSignal(actionName, "ActionTriggered", "Began", key)
	end
end

function InputService._inputEnded(self: InputService, key: input)
	if not self._keyActions[key] then
		return
	end

	for _, actionName in ipairs(self._keyActions[key]) do
		local actionData = self._actions[actionName]
		if not actionData or not self._contexts[actionData.context] then
			continue
		end

		self:_fireSignal(actionName, "ActionEnded", key)
		self:_fireSignal(actionName, "ActionTriggered", "Ended", key)
	end
end

function InputService._fireSignal(self: InputService, actionName: string, inputType: string, ...: any)
	local signal = self._signals[inputType][actionName]
	if signal then
		signal:Fire(...)
	end
end

function InputService._clearTable(self: InputService)
	for key, actions in pairs(self._keyActions) do
		if #actions > 0 then
			continue
		end

		self._keyActions[key] = nil
	end

	for _, signals in self._signals do
		for i, signal: Signal.Signal<any> in signals do
			if #signal:GetConnections() > 0 then
				continue
			end

			signal:Destroy()
			signals[i] = nil
		end
	end
end

function InputService._retrieveSignal(self: InputService, actionName: string, signalType: string)
	if not self._signals[signalType][actionName] then
		self._signals[signalType][actionName] = Signal.new()
	end

	return self._signals[signalType][actionName]
end

export type InputService = typeof(InputService)

return InputService
