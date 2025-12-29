local Hoverboards = {
	Hoverboard1 = {
		TopSpeed = 65,
		Acceleration = 1,
		JumpPower = 80,
		Price = 1,
		Currency = "Coins",
		Image = "rbxassetid://18566592803",
	},
	Hoverboard2 = {
		TopSpeed = 80,
		Acceleration = 1.1,
		JumpPower = 41,
		Price = 1,
		Currency = "Coins",
		Image = "rbxassetid://18566592803",
	}
}

function Hoverboards.GetConfig(name)
	return Hoverboards[name]
end

return Hoverboards

