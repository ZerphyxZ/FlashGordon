local function CubicBezier(x)
	-- Control points
	local x1, y1 = 0.11, 0
	local x2, y2 = 0.5, 0

	-- Evaluate cubic bezier at parameter t
	local function sampleCurveX(t)
		local inv = 1 - t
		return (3 * x1 * inv^2 * t)
			+ (3 * x2 * inv * t^2)
			+ (t^3)
	end

	local function sampleCurveY(t)
		local inv = 1 - t
		return (3 * y1 * inv^2 * t)
			+ (3 * y2 * inv * t^2)
			+ (t^3)
	end

	-- Derivative of x(t)
	local function sampleCurveDerivativeX(t)
		local inv = 1 - t
		return (3 * x1 * (-2 * inv * t + inv^2))
			+ (3 * x2 * (-t^2 + 2 * inv * t))
			+ (3 * t^2)
	end

	-- Solve x(t) = x for t using Newton-Raphson
	local t = x
	for _ = 1, 8 do
		local xEst = sampleCurveX(t) - x
		if math.abs(xEst) < 1e-7 then break end
		local d = sampleCurveDerivativeX(t)
		if math.abs(d) < 1e-7 then break end
		t = t - xEst / d
	end

	-- Clamp t to range
	t = math.clamp(t, 0, 1)

	-- Return y(t)
	return sampleCurveY(t)
end

return CubicBezier
