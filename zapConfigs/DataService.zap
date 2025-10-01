opt server_output = "../src/network/Server/DataServiceNetwork.luau"
opt client_output = "../src/network/Client/DataServiceNetwork.luau"

opt remote_scope = "DataService"
opt casing = "PascalCase"

opt yield_type = "promise"
opt async_lib = "require(game:GetService('ReplicatedStorage').Packages.Promise)"

opt disable_fire_all = true

event InitialDataSync = {
	from: Server,
	type: Reliable,
	call: SingleAsync,
	data: map { [string.utf8]: unknown },
}

event DataUpdate = {
	from: Server,
	type: Reliable,
	call: SingleAsync,
	data: struct {
		Key: string.utf8,
		Value: unknown
	}
}