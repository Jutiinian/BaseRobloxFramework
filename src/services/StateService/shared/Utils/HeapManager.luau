--!strict

-- || Services || --
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- || Dependencies || --
local StateServiceTypes = require(ReplicatedStorage.Services.StateService.StateServiceTypes)

-- || Types || --
export type HeapEntry = {
	ExpiresAt: number,
	ID: number,
	Key: string,
	StateRef: StateServiceTypes.StateData,
}

type OnExpiredCallback = (entry: HeapEntry) -> ()

-- || Public API || --
local HeapManager = {}
HeapManager.__index = HeapManager

export type HeapManager = typeof(setmetatable(
	{} :: {
		_heap: { HeapEntry },
		_heapSize: number,
		_schedulerThread: thread?,
		_onExpired: OnExpiredCallback,
	},
	HeapManager
))

function HeapManager.new(onExpired: OnExpiredCallback): HeapManager
	return setmetatable({
		_heap = {} :: { HeapEntry },
		_heapSize = 0,
		_schedulerThread = nil,
		_onExpired = onExpired,
	}, HeapManager) :: any
end

function HeapManager.Push(self: HeapManager, entry: HeapEntry)
	self._heapSize += 1
	self._heap[self._heapSize] = entry

	local i = self._heapSize
	while i > 1 do
		local parent = math.floor(i / 2)
		if self._heap[parent].ExpiresAt <= self._heap[i].ExpiresAt then
			break
		end

		self._heap[parent], self._heap[i] = self._heap[i], self._heap[parent]
		i = parent
	end
end

function HeapManager.Pop(self: HeapManager): HeapEntry?
	if self._heapSize == 0 then
		return nil
	end

	local top = self._heap[1]
	self._heap[1] = self._heap[self._heapSize]
	self._heap[self._heapSize] = nil :: any
	self._heapSize -= 1

	local i = 1
	while true do
		local left = i * 2
		local right = i * 2 + 1
		local smallest = i

		if left <= self._heapSize and self._heap[left].ExpiresAt < self._heap[smallest].ExpiresAt then
			smallest = left
		end

		if right <= self._heapSize and self._heap[right].ExpiresAt < self._heap[smallest].ExpiresAt then
			smallest = right
		end

		if smallest == i then
			break
		end

		self._heap[i], self._heap[smallest] = self._heap[smallest], self._heap[i]

		i = smallest
	end

	return top
end

function HeapManager.Peek(self: HeapManager): HeapEntry?
	return if self._heapSize > 0 then self._heap[1] else nil
end

function HeapManager.ScheduleNext(self: HeapManager)
	if self._schedulerThread then
		task.cancel(self._schedulerThread)
		self._schedulerThread = nil
	end

	if self._heapSize == 0 then
		return
	end

	local delay = math.max(0, self._heap[1].ExpiresAt - os.clock())
	self._schedulerThread = task.delay(delay, function()
		self:_drainHeap()
	end)
end

function HeapManager._drainHeap(self: HeapManager)
	self._schedulerThread = nil
	local now = os.clock()

	while self._heapSize > 0 do
		local top = self._heap[1]
		if top.ExpiresAt > now then
			break
		end
		self:Pop()
		self._onExpired(top)
	end

	self:ScheduleNext()
end

return HeapManager
