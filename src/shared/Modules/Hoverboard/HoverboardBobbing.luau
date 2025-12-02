-- Add bobbing variables at the top of the script (after other constants)
local BOB_AMPLITUDE = 10 -- How much the hoverboard moves up and down
local BOB_SPEED = 3 -- How fast the bobbing happens
local BOB_SMOOTHNESS = 5 -- How smooth the bobbing transition is
local bobbingActive = false
local bobTime = 0
local originalCameraType = "Custom"

local HoverboardBobbing = {}

-- Add this function to handle bobbing
function HoverboardBobbing.Update(dt, moveDir, currentSpeed, workspace, hoverboard, bodyPosition)
    local cam = workspace.CurrentCamera
    
    -- Determine if we should bob (not moving and not throttling)
    local shouldBob = currentSpeed == 0 and moveDir.Magnitude <= 0.1
    
    -- Handle camera type switching
    if shouldBob ~= bobbingActive then
        bobbingActive = shouldBob
        
        if bobbingActive then
            -- Start bobbing: save current camera type and switch to Fixed
            if cam then
                originalCameraType = cam.CameraType.Name
                cam.CameraType = Enum.CameraType.Fixed
            end
            bobTime = 0
        else
            -- Stop bobbing: restore original camera type
            if cam then
                cam.CameraType = Enum.CameraType[originalCameraType] or Enum.CameraType.Custom
            end
        end
    end
    
    -- Apply bobbing effect
    if bobbingActive and hoverboard and hoverboard.PrimaryPart and bodyPosition then
        bobTime = bobTime + dt * BOB_SPEED
        
        -- Calculate bobbing offset using sine wave
        local bobOffset = math.sin(bobTime) * BOB_AMPLITUDE
        
        -- Smoothly apply the bobbing offset to the hoverboard's position
        local primary = hoverboard.PrimaryPart
        local origin = primary.Position
        local targetY = origin.Y + bobOffset
        
        -- Smooth the position change
        local smoothFactor = 1 - math.exp(-BOB_SMOOTHNESS * dt)
        local currentY = bodyPosition.Position.Y
        local newY = currentY + (targetY - currentY) * smoothFactor
        
        bodyPosition.Position = Vector3.new(origin.X, newY, origin.Z)
    end
end

return HoverboardBobbing