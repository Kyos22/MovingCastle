--[[
	HOW TO USE:
	If you added a system on the server or the client, you must type the system name here with the the correct name and location in order for the system to work
	Set enabled to false if you don't want the system to work yet
	Set piority value to low if you want the code to run immediately on start
	Set piority value to high if the code does not neeed to run immediately (recommended if the system is only triggered by players)
]]

type Feature = {
	Enabled: boolean,
	Priority: number,
}

type YumiFeatures = {
	[string]: {
		[string]: {
			[string]: Feature,
		},
	},
	Yumi: {
		PrintLog: string,
	},
}

local Features: YumiFeatures = {
	Systems = {
		Client = {
			["Highlight"] = {
				Enabled = true,
				Priority = 10,
			},
			["Interface"] = {
				Enabled = true,
				Priority = 10,
			},
			["Profile"] = {
				Enabled = true,
				Priority = 10,
			},
			["Display"] = {
				Enabled = true,
				Priority = 20,
			},
			["Camera"] = {
				Enabled = true,
				Priority = 20,
			},
			["Castle"] = {
				Enabled = true,
				Priority = 20,
			},
		},

		Server = {
			["Profile"] = {
				Enabled = true,
				Priority = 10,
			},
			["TextChatService"] = {
				Enabled = true,
				Priority = 10,
			},
			["Player"] = {
				Enabled = true,
				Priority = 10,
			},
			["Castle"] = {
				Enabled = true,
				Priority = 10,
			},
		},
	},
	Observers = {
		Client = {
			["Profile"] = {
				Enabled = true,
				Priority = 10,
			},

		},

		Server = {
			["Profile"] = {
				Enabled = true,
				Priority = 10,
			},
			["PlayerObserver"] = {
				Enabled = true,
				Priority = 10,
			},
		},
	},
	Yumi = {
		["PrintLog"] = 1,
	},
}

return Features
