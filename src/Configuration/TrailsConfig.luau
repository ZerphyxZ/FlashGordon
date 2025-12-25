local TrailsConfig = {
    RedTrail = {
        Name = "Red Trail",
        Description = "Red Trail, follows behind the board or your character",
        Price = 5,
        Color = Color3.fromRGB(255, 0, 0),
        Image = "",
        Currency = "Coins",
    },
    YellowTrail = {
        Name = "Yellow Trail",
        Description = "Yellow Trail, follows behind the board or your character",
        Price = 5,
        Color = Color3.fromRGB(255, 255, 0),
        Image = "",
        Currency = "Coins",
    },
    BlueTrail = {
        Name = "Blue Trail",
        Description = "Blue Trail, follows behind the board or your character",
        Price = 5,
        Color = Color3.fromRGB(0, 123, 255),
        Image = "",
        Currency = "Coins",
    },
    GreenTrail = {
        Name = "Green Trail",
        Description = "Green Trail, follows behind the board or your character",
        Price = 5,
        Color = Color3.fromRGB(0, 255, 0),
        Image = "",
        Currency = "Coins",
    },
}

function TrailsConfig.GetConfig(name)
	return TrailsConfig[name]
end

return TrailsConfig