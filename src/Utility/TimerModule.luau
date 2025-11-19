local TimerModule = {}

function TimerModule.Timer(player, number)
	if number < 0 then
		return "0:00"
	end
	local hours = math.floor(number / 60 / 60)
	local minutes = math.floor(number / 60) % 60
	local seconds = math.floor(number % 60)

	if minutes < 10 then
		minutes = "0" .. minutes
	end

	if seconds < 10 then
		seconds = "0" .. seconds
	end

	return hours .. ":" .. minutes .. ":" .. seconds
end

return TimerModule
