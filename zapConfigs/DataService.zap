opt server_output = "../src/network/Server/DataServiceNetwork.luau"
opt client_output = "../src/network/Client/DataServiceNetwork.luau"

opt remote_scope = "DataService"
opt casing = "PascalCase"

opt yield_type = "promise"
opt async_lib = "require(game:GetService('ReplicatedStorage').Packages.Promise)"

opt disable_fire_all = true

type Value = (
	f64
	| boolean
	| string.utf8
	| unknown
)

event InitialDataSync = {
	from: Server,
	type: Reliable,
	call: SingleAsync,
	data: map { [string.utf8]: Value },
}

type indexPath = enum "Type" {
    String { value: string.utf8 },
    Table { value: string.utf8[] },
}

event DataUpdate = {
	from: Server,
	type: Reliable,
	call: SingleAsync,
	data: struct {
		Key: indexPath,
		Value: Value
	}
}