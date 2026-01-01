local Hoverboards = {
	Hoverboard1 = {
		TopSpeed = 55,
		Acceleration = 1,
		JumpPower = 39,
		Price = 1,
		Currency = "Coins",
		Image = "rbxassetid://18566592803",
	},
	Hoverboard2 = {
		TopSpeed = 60,
		Acceleration = 1.05,
		JumpPower = 39,
		Price = 1,
		Currency = "Coins",
		Image = "rbxassetid://18566592803",
	},
	Hoverboard3 = {
		TopSpeed = 65,
		Acceleration = 1.1,
		JumpPower = 40,
		Price = 1,
		Currency = "Coins",
		Image = "rbxassetid://18566592803",
	},
	Hoverboard4 = {
		TopSpeed = 70,
		Acceleration = 1.15,
		JumpPower = 43,
		Price = 1,
		Currency = "Coins",
		Image = "rbxassetid://18566592803",
	},
	Hoverboard5 = {
		TopSpeed = 75,
		Acceleration = 1.15,
		JumpPower = 41,
		Price = 1,
		Currency = "Coins",
		Image = "rbxassetid://18566592803",
	},
	Hoverboard6 = {
		TopSpeed = 80,
		Acceleration = 1.2,
		JumpPower = 42,
		Price = 1,
		Currency = "Coins",
		Image = "rbxassetid://18566592803",
	},
	Hoverboard7 = {
		TopSpeed = 85,
		Acceleration = 1.25,
		JumpPower = 44,
		Price = 1,
		Currency = "Coins",
		Image = "rbxassetid://18566592803",
	},
	Hoverboard8 = {
		TopSpeed = 90,
		Acceleration = 1.3,
		JumpPower = 50,
		Price = 1,
		Currency = "Coins",
		Image = "rbxassetid://18566592803",
	},
	Hoverboard9 = {
		TopSpeed = 95,
		Acceleration = 1.35,
		JumpPower = 51,
		Price = 1,
		Currency = "Coins",
		Image = "rbxassetid://18566592803",
	},
	Hoverboard10 = {
		TopSpeed = 100,
		Acceleration = 1.4,
		JumpPower = 55,
		Price = 1,
		Currency = "Coins",
		Image = "rbxassetid://18566592803",
	},
}

function Hoverboards.GetConfig(name)
	return Hoverboards[name]
end

return Hoverboards

