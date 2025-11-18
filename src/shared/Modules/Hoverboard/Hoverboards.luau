local Hoverboards = {
	Default = {
		TopSpeed = 55,
		Acceleration = 0.7,
		Deceleration = 3.5,
		JumpPower = 60,
		Boost = {
			RefillTime = 5,
			Power = 1.5,
		},
		Flash = {
			Speed = 100,
			Duration = 0.8,
			VFX = "FlashEffect1",
		},
	},
	BoostRider = {
		TopSpeed = 50,
		Acceleration = 1.5,
		Deceleration = 1.2,
		JumpPower = 70,
		Boost = {
			RefillTime = 6,
			Power = 2,
		},
		Flash = {
			Speed = 120,
			Duration = 0.5,
			VFX = "FlashEffect2",
		},
	},
}

function Hoverboards.GetConfig(name)
	return Hoverboards[name]
end

return Hoverboards

