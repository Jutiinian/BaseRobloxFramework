--!optimize 2

-- Modules
local Runtime = require(script.Parent.Parent.Runtime)

local actor = script:GetActor()

actor:BindToMessage("init", Runtime.init)
actor:BindToMessage("register", Runtime.register)
actor:BindToMessage("unregister", Runtime.unregister)
actor:BindToMessage("setProperty", Runtime.setProperty)
actor:BindToMessageParallel("emit", Runtime.emit)
actor:BindToMessageParallel("dispatch", Runtime.dispatch)