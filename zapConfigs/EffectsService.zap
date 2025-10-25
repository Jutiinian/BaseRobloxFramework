opt server_output = "../src/network/Server/EffectsServiceNetwork.luau"
opt client_output = "../src/network/Client/EffectsServiceNetwork.luau"

opt remote_scope = "EffectsService"
opt casing = "PascalCase"

opt yield_type = "promise"
opt async_lib = "require(game:GetService('ReplicatedStorage').Packages.Promise)"

type listArgument = unknown

type effectArguments = enum "Effect" {
    Template {
        value: struct {
            Position: vector,
            Radius: u16(..20000)
        }
    },

    
}

event ReplicateEffectReliable = {
    from: Server,
    type: Reliable,
    call: SingleAsync,
    data: struct {
        Effect: string.utf8(..25),
        Arguments: effectArguments
    }
}

event ReplicateEffectUnreliable = {
    from: Server,
    type: Unreliable,
    call: SingleAsync,
    data: struct {
        Effect: string.utf8(..20),
        Arguments: effectArguments
    }
}