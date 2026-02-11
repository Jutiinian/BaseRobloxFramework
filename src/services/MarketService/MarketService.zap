opt server_output = "./network/Server.luau"
opt client_output = "./network/Client.luau"

opt remote_scope = "MarketService"
opt casing = "PascalCase"

opt yield_type = "promise"
opt async_lib = "require(game:GetService('ReplicatedStorage').Packages.promise)"

opt disable_fire_all = true

event InitializeMarketData = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: map { [string.utf8]: boolean }
}

event SetMarketData = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: (Index: string.utf8, Value: boolean)
}

funct RequestGiftPurchase = {
    call: Async,
    args: (Recipient: string.utf8, ProductID: string.utf8),
    rets: boolean
}