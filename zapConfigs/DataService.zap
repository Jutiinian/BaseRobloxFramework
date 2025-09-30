opt server_output = "../src/network/Server/DataServiceNetwork.luau"
opt client_output = "../src/network/Client/DataServiceNetwork.luau"

opt remote_scope = "DataService"
opt casing = "PascalCase"

event AmGay = {
	from: Server,
	type: Reliable,
	call: ManyAsync,
	data: (Foo: u32, Bar: string.utf8),
}