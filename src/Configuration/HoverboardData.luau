local Hoverboards = {
	Hoverboard1 = {
		TopSpeed = 60,
		Acceleration = 1,
		JumpPower = 80,
	},
	Hoverboard2 = {
		TopSpeed = 80,
		Acceleration = 1.1,
		JumpPower = 41,
	},
	Hoverboard3 = {
		TopSpeed = 100,
		Acceleration = 1.1,
		JumpPower = 40,
	}
}

function Hoverboards.GetConfig(name)
	return Hoverboards[name]
end

return Hoverboards

