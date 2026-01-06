opt server_output = "src/Shared/Network/Server.luau"
opt client_output = "src/Shared/Network/Client.luau"
opt casing = "PascalCase"
opt write_checks = true
opt yield_type = "future"
opt async_lib = "require(game:GetService('ReplicatedStorage').Packages.Future)"

-- INTEGRATION TESTING


----PlayerProfile
event Player_Update_Profile = {
    from: Server,
	type: Reliable,
	call: ManyAsync,
	data: (unknown)
}

--------- profile--------------
funct Get_Profile = {
    call: Async,
    args: (async: boolean?),
    rets: (unknown)
}
---------- car ---------------
event car_move = {
    from: Client,
	type: Reliable,
	call: ManyAsync,
	data: (throttle: i8, steer: i8)
}