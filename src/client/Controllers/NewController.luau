local Global = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Modules"):WaitForChild(
    "Global"))
local Knit = Global.Knit
local NewController = Knit.CreateController({
    Name = "NewController"
})

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")
local player = Players.LocalPlayer
local character
local humanoid
local Board
local invisiblePart
local Trail
local rootPart
local bodyVelocity
local vf
local bodyGyro
local Camera = workspace.Camera
local Config

-- MODULES
local Configuration = ReplicatedStorage:WaitForChild("Configuration")
local HoverboardData = require(Configuration:WaitForChild("HoverboardData"))
local TrailsConfig = require(Configuration:WaitForChild("TrailsConfig"))
local DashTrailModule = ReplicatedStorage:WaitForChild("VFX"):WaitForChild("HoverboardVFX"):WaitForChild("ElectricDash")
local HoverboardService
local GearService
local ProductsService
local ProductsController

-- MOVEMENT / ORIENTATION
local RayDistance = 10
local HorizontalTiltAngle = 0

-- CONSTANT VALUES
local DECELERATION_FACTOR = 0.5
local ORIENTATION_FACTOR = 10
local MAX_HORIZONTAL_TILT = 15
local FOV_FACTOR = 1
local FLOATING_ERROR_MARGIN = 0.01
local JUMP_POWER = 70
local MAX_SPEED = 100
local ACCELERATION = 0.3
local DOWNHILL_SLOPE_ANGLE = 90 -- angle at which board gets max downhill boost (clamped in code)
local RAY_PREFERENCE_DISTANCE = 0
local MIN_FOV = 70
local MAX_FOV = 100

-- WALL AVOIDANCE: single ray from character, turns board to opposite direction on hit.
local WALL_RAY_LENGTH     = 5     -- studs ahead of character to detect walls
local WALL_TURN_SMOOTH    = 30     -- exponential lerp speed for the U-turn redirect

-- SMOOTH LANDING: absorb hard fall impact without touching slope / jump behaviour.
-- Only fires when the board is grounded AND vertical velocity is significantly negative.
local LANDING_THRESHOLD   = -18    -- Y velocity (studs/s) that counts as a hard landing
local LANDING_ABSORB      = 0.08   -- fraction of impact Y that survives (0 = full stop)

-- MOVEMENT / SPEED
local IsDecelerating = false
local IsBraking = true
local Diff = 0.01
NewController.SpeedVar = 0
NewController.CurrentSpeed = 0
local acceleration
local topSpeed
local jumpPower

-- JUMP
local grounded = false
local rayHit = false
local spaceHeld = false
local totalJumps = 0
local canDoubleJump = false
local canFly = false

-- FLY
local MAX_JUMPS = 6
local MAX_FLY_ENERGY = 100
local FLY_DRAIN_TIME = 1 -- seconds to go from 100 → 0 while flying
local FLY_REFILL_TIME = 2 -- seconds to go from 0 → 100 on ground
local DRAIN_RATE = MAX_FLY_ENERGY / FLY_DRAIN_TIME
local REFILL_RATE = MAX_FLY_ENERGY / FLY_REFILL_TIME
local flyEnergy = MAX_FLY_ENERGY

-- CONNECTIONS
local runningConnection

-- State
local hoverboard
local runningConnection
local isHoverboardInitialized = false
local isBoosting = false
local boostReady = true
local isDashing = false
local dashReady = true
local isJumping = false
local isFlying = false
local isFalling = false
local isBraking = false
local flipping = false
local flipAngle = 0

-- Boost config
local BOOST_DURATION = 1
local BOOST_AMOUNT = 2.5
local BOOST_COOLDOWN = 3

-- Dash config
local DASH_DURATION = 0.25
local DASH_DISTANCE = 50
local DASH_AMOUNT = 4000
local DASH_COOLDOWN = 3

-- UI References
local playerGUI = player:WaitForChild("PlayerGui")
local gameHUD = playerGUI:WaitForChild("GameHUD")
local mainGUI = playerGUI:WaitForChild("MainGui")
local speedGUI = gameHUD:WaitForChild("SpeedGUI")
local speedLabel = speedGUI:WaitForChild("SpeedVal")
local speedFrame = speedGUI:WaitForChild("Frame")

-- BOOST UI
local boostFrame = gameHUD:WaitForChild("BoostFrame")
local boostButton = boostFrame:WaitForChild("BoostButton")
local boostCooldownFiller = boostFrame:WaitForChild("CooldownFill")

-- FLASH UI
local flashFrame = gameHUD:WaitForChild("FlashFrame")
local flashButton = flashFrame:WaitForChild("FlashButton")
local flashCooldownFiller = flashFrame:WaitForChild("CooldownFill")

local controls
local RayParams
local wallDetected

local motor
local BASE_C0
local BASE_C1
local FLIP_DURATION = 0.45 -- seconds
local FLIP_ANGLE = math.pi * 2 -- 360°
local FLIP_SPEED = FLIP_ANGLE / FLIP_DURATION

local function GetControls()
    if controls then
        return controls
    end
    local playerScripts = player:WaitForChild("PlayerScripts")
    controls = require(playerScripts:WaitForChild("PlayerModule")):GetControls()
    return controls
end

local function InitBodyMovers()
    bodyVelocity = Board:WaitForChild("BodyVelocity")
    bodyGyro = Board:WaitForChild("BodyGyro")
end

local function SetCollisionGroup(model, groupName)
    for _, inst in ipairs(model:GetDescendants()) do
        if inst:IsA("BasePart") then
            inst.CollisionGroup = groupName
        end
    end
end

function WallDetection(dt)
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.IgnoreWater = true
    rayParams.FilterDescendantsInstances = {character, Board}

    local velocity = Board.AssemblyLinearVelocity
    -- local velocity = bodyVelocity.Velocity
    local speed = velocity.Magnitude
    if speed <= 0.1 then
        return
    end
    local lookDir = velocity.Unit
    local cframe = Board.CFrame
    local objectLookDir = cframe:VectorToObjectSpace(lookDir)
    local halfSize = Board.Size / 2
    -- local offset = lookDir.X * halfSize.X + lookDir.Y * halfSize.Y + lookDir.Z * halfSize.Z
    local objectOffset = Vector3.new(objectLookDir.X * halfSize.X, objectLookDir.Y * halfSize.Y,
        objectLookDir.Z * halfSize.Z)
    local worldOffset = cframe:VectorToWorldSpace(objectOffset)
    -- local origin = Board.Position + lookDir * offset
    local origin = Board.Position + worldOffset
    local rayLength = math.max(2, speed * dt + 1)
    local direction = lookDir * rayLength

    local hit = workspace:Raycast(origin, direction, rayParams)
    if hit and hit.Instance and hit.Instance:IsA("BasePart") then
        if hit.Instance.CollisionGroup ~= "Walls" then
            return
        end

        print("Wall detected!")

        local normal = hit.Normal
        -- Check if moving into wall
        local intoWall = velocity:Dot(normal)

        if intoWall < 0 then
            -- Push slightly opposite to wall normal
            local pushStrength = 200 -- adjust this for how strong push back is
            -- local pushStrength = math.clamp(speed * 2, 100, 200)
            local pushDirection = normal * pushStrength

            -- Keep Y velocity untouched (optional)
            local targetVelocity = Vector3.new(pushDirection.X, velocity.Y, pushDirection.Z)

            -- Smooth transition using Lerp
            -- local smoothFactor = math.clamp(speed * 0.12, 8, 25) -- stronger push at higher speeds
            local smoothFactor = 5
            local alpha = 1 - math.exp(-smoothFactor * dt) -- exponential smoothing

            -- bodyVelocity.Velocity = velocity:Lerp(targetVelocity, alpha)
            Board.AssemblyLinearVelocity = velocity:Lerp(targetVelocity, alpha)
        end
    end

    -- OLD CODE
    -- local rayParams = RaycastParams.new()
    -- rayParams.FilterType = Enum.RaycastFilterType.Exclude
    -- rayParams.IgnoreWater = true
    -- rayParams.FilterDescendantsInstances = {character, Board}

    -- local lookDir = rootPart.CFrame.LookVector
    -- local speed = Board.AssemblyLinearVelocity.Magnitude
    -- -- local speed = bodyVelocity.Velocity.Magnitude

    -- -- Dynamic ray length (prevents tunneling)
    -- local rayLength = math.max(5, speed * dt + 1)

    -- local origin = rootPart.Position
    -- local direction = lookDir * rayLength

    -- local hit = workspace:Raycast(origin, direction, rayParams)

    -- if hit then
    --     print("Wall detected!")
    --     local normal = hit.Normal
    --     local currentVel = Board.AssemblyLinearVelocity
    --     -- local currentVel = bodyVelocity.Velocity

    --     -- Slide with the wall
    --     local intoWall = currentVel:Dot(normal)
    --     local slideVelocity = currentVel - normal * intoWall
    --     -- local maxSlideSpeed = currentVel.Magnitude
    --     -- slideVelocity = slideVelocity.Unit * math.min(slideVelocity.Magnitude, maxSlideSpeed)
    --     if intoWall < 0 then
    --         -- Board.AssemblyLinearVelocity = Vector3.new(slideVelocity.X * 0, currentVel.Y, slideVelocity.Z * 0)
    --         bodyVelocity.Velocity = Vector3.new(slideVelocity.X * 0.95, 0, slideVelocity.Z * 0.95)
    --     end
    --     --return
    -- end
end

function GetMaxJumps()
    if ProductsController then
        if ProductsController.HasFly then
            return MAX_JUMPS
        end
        if ProductsController.HasDoubleJump then
            return 2
        end
    end
    return 1
end

------------------- UPDATE SPEED GUI -----------------------
function UpdateSpeedGUI(topSpeed)
    if not bodyVelocity or not topSpeed or topSpeed <= 0 then
        return
    end

    local speed = (bodyVelocity.Velocity * Vector3.new(1, 0, 1)).Magnitude or 0
    speedLabel.Text = string.format("Speed: %.0f", math.round(speed))
    local alpha = math.clamp(speed / topSpeed, 0, 1)
    speedFrame.Size = UDim2.new(alpha, 0, speedFrame.Size.Y.Scale, 0)
end
-----------------------------------------------------------

--------------------- BOOST MODULE ------------------------
local function RefreshBoostGUI()
    if boostCooldownFiller then
        boostCooldownFiller.Visible = false
        boostCooldownFiller.Size = UDim2.new(1, 0, 0, 0)
    end
end

function ApplyBoost(boostDuration, boostAmount)
    if not humanoid or not Board or not bodyVelocity then
        return
    end
    if not boostReady or isBoosting then
        return
    end
    if humanoid.MoveDirection.Magnitude < 0.1 then
        return
    end

    -- Current horizontal speed
    local currentVel = bodyVelocity.Velocity
    local horizontalVel = Vector3.new(currentVel.X, 0, currentVel.Z)

    if horizontalVel.Magnitude < 20 then
        return
    end

    boostButton.Interactable = false
    boostReady = false
    isBoosting = true

    local boostDir = horizontalVel.Magnitude > 0 and horizontalVel.Unit or humanoid.MoveDirection
    local boostStartTime = tick()
    local boostEndTime = boostStartTime + boostDuration

    local boostConnection
    boostConnection = RunService.Heartbeat:Connect(function(dt)
        if not Board or not isBoosting then
            if boostConnection then
                boostConnection:Disconnect()
            end
            return
        end

        if tick() >= boostEndTime then
            isBoosting = false
            boostConnection:Disconnect()

            -- Clamp back to topSpeed after boost ends
            local v = bodyVelocity.Velocity
            local flat = Vector3.new(v.X, 0, v.Z)

            if flat.Magnitude > topSpeed then
                local clamped = flat.Unit * topSpeed
                bodyVelocity.Velocity = Vector3.new(clamped.X, v.Y, clamped.Z)
            end
            return
        end

        -- Inject boost velocity (preserve Y)
        bodyVelocity.Velocity = bodyVelocity.Velocity +
                                    Vector3.new(boostDir.X * boostAmount * dt * 60, 0,
                boostDir.Z * boostAmount * dt * 60)
    end)

    -- Cooldown
    if boostCooldownFiller then
        boostCooldownFiller.Visible = true
        boostCooldownFiller.Size = UDim2.new(1, 0, 1, 0)
    end
    task.spawn(function()
        local step = 0.05
        local timeLeft = BOOST_COOLDOWN

        while timeLeft > 0 do
            if boostCooldownFiller then
                boostCooldownFiller.Size = UDim2.new(1, 0, timeLeft / BOOST_COOLDOWN, 0)
            end
            timeLeft = timeLeft - step
            task.wait(step)
        end

        boostReady = true
        if boostCooldownFiller then
            boostCooldownFiller.Visible = false
            boostCooldownFiller.Size = UDim2.new(1, 0, 0, 0)
        end
        boostButton.Interactable = true
    end)
end
-----------------------------------------------------------

--------------------- FLASH MODULE ------------------------
-- VFX: attach electric trails to player body parts
local BODY_PARTS = {"Head", "LeftFoot", "LeftHand", "LeftLowerArm", "LeftLowerLeg", "LeftUpperArm", "LeftUpperLeg",
                    "LowerTorso", "RightFoot", "RightHand", "RightLowerArm", "RightLowerLeg", "RightUpperArm",
                    "RightUpperLeg", "UpperTorso"}

local function RefreshFlashGUI()
    if flashCooldownFiller then
        flashCooldownFiller.Visible = false
        flashCooldownFiller.Size = UDim2.new(1, 0, 0, 0)
    end
end

local function CloneVFX()
    NewController._activeVFX = {}
    for _, partName in ipairs(BODY_PARTS) do
        local part = character:FindFirstChild(partName)
        if part then
            -- Clone the whole folder
            local fxFolder = DashTrailModule:Clone()
            fxFolder.Name = "ElectricDash_VFX_" .. partName

            -- Extract the objects BEFORE re-parenting
            local attach = fxFolder:FindFirstChild("ParticleAttachment")
            local particleEmitter = fxFolder:FindFirstChild("ParticleEmitter")

            if attach then
                attach.Parent = part
            end
            if particleEmitter then
                particleEmitter.Parent = part
                particleEmitter.Enabled = false
            end

            -- store the trails ONLY (they are what we toggle)
            table.insert(NewController._activeVFX, {
                ParticleEmitter = particleEmitter
            })

            -- destroy the empty folder now
            fxFolder:Destroy()
        end
    end
end

local function EnableFlashVFX(enable)
    for _, fx in ipairs(NewController._activeVFX or {}) do
        if fx.ParticleEmitter then
            print("VFX Enabled")
            fx.ParticleEmitter.Enabled = enable
        end
    end
end

local function MakePlayerInvincible(state)
    character:SetAttribute("Invincible", state)
    local groupName = state and "PlayerInvincible" or "Player"

    SetCollisionGroup(character, groupName)
    if Board and Board.Parent then
        SetCollisionGroup(Board.Parent, groupName)
    end
end

function ApplyDash(dashAmount, dashDuration, dashDistance)
    if not humanoid or not Board or not bodyVelocity then
        return
    end

    if not dashReady or isDashing then
        return
    end

    if humanoid.MoveDirection.Magnitude < 0.1 then
        return
    end

    -- Store the current direction BEFORE applying dash
    local currentVel = Board.AssemblyLinearVelocity
    local horizontalVel = Vector3.new(currentVel.X, 0, currentVel.Z)

    -- CRITICAL: Store dash direction ONCE at the start
    local initialDashDir = humanoid.MoveDirection -- or horizontalVel.Magnitude > 0 and horizontalVel.Unit
    initialDashDir = Vector3.new(initialDashDir.X, 0, initialDashDir.Z).Unit

    if horizontalVel.Magnitude < 20 then
        print("Not enough speed.")
        return
    end

    print("Dash applied.")
    dashReady = false
    isDashing = true
    flashButton.Interactable = false
    EnableFlashVFX(true)

    -- Calculate required speed for distance-based dash
    local requiredSpeed = dashDistance / dashDuration
    local dashStartTime = tick()
    local dashEndTime = dashStartTime + dashDuration

    local originalTopSpeed = topSpeed
    local lockedDashDir = initialDashDir

    -- Disable humanoid control during dash (optional but recommended)
    local wasAutoRotate = humanoid.AutoRotate
    humanoid.AutoRotate = false

    local dashConnection
    dashConnection = RunService.Heartbeat:Connect(function(dt)
        if not Board or not isDashing then
            if dashConnection then
                dashConnection:Disconnect()
            end
            -- Restore humanoid control
            humanoid.AutoRotate = wasAutoRotate
            MakePlayerInvincible(false)
            EnableFlashVFX(false)
            return
        end

        local currentTime = tick()
        local elapsed = currentTime - dashStartTime

        -- Stop dash after duration
        if currentTime >= dashEndTime then
            isDashing = false
            MakePlayerInvincible(false)
            EnableFlashVFX(false)

            -- Restore original settings
            topSpeed = originalTopSpeed
            humanoid.AutoRotate = wasAutoRotate

            -- Apply post-dash velocity (keep momentum but prevent excessive speed)
            local v = Board.AssemblyLinearVelocity
            local flat = Vector3.new(v.X, 0, v.Z)

            -- Calculate velocity decay
            local currentSpeed = flat.Magnitude

            if currentSpeed > originalTopSpeed then
                -- Smooth deceleration to normal speed
                local deceleration = (currentSpeed - originalTopSpeed) * 0.8
                local newSpeed = math.max(currentSpeed - deceleration * dt, originalTopSpeed)
                local newVel = flat.Unit * newSpeed
                Board.AssemblyLinearVelocity = Vector3.new(newVel.X, v.Y, newVel.Z)
            end

            if dashConnection then
                dashConnection:Disconnect()
            end

            return
        end
        -- Make the player invicible
        MakePlayerInvincible(true)
        local progress = elapsed / dashDuration

        -- Apply easing for better feel (ease-out quad)
        local easeFactor = 1 - (1 - progress) * (1 - progress)
        local currentDashSpeed = requiredSpeed * (0.9 + 0.2 * easeFactor)

        local vel = Board.AssemblyLinearVelocity
        Board.AssemblyLinearVelocity = Vector3.new(lockedDashDir.X * currentDashSpeed, -- Always use locked direction
        vel.Y, -- Preserve vertical velocity
        lockedDashDir.Z * currentDashSpeed -- Always use locked direction
        )
    end)

    -- Cooldown management
    if flashCooldownFiller then
        flashCooldownFiller.Visible = true
        flashCooldownFiller.Size = UDim2.new(1, 0, 1, 0)
    end
    task.spawn(function()
        local step = 0.05
        local timeLeft = DASH_COOLDOWN

        while timeLeft > 0 do
            if flashCooldownFiller then
                local progress = 1 - (timeLeft / DASH_COOLDOWN)
                local sizeProgress = progress * progress
                flashCooldownFiller.Size = UDim2.new(1, 0, 1 - sizeProgress, 0)
            end
            timeLeft = timeLeft - step
            task.wait(step)
        end

        dashReady = true
        if flashCooldownFiller then
            flashCooldownFiller.Visible = false
            flashCooldownFiller.Size = UDim2.new(1, 0, 0, 0)
        end
        flashButton.Interactable = true
    end)
end

function Dash(dashPower)
    if not Board or not humanoid then
        return
    end

    -- Cooldown / state checks
    if not dashReady or isDashing then
        return
    end

    local velocity = Board.AssemblyLinearVelocity
    local horizontal = Vector3.new(velocity.X, 0, velocity.Z)

    if horizontal.Magnitude < 0.1 then
        return
    end

    -- ===== DASH START =====
    dashReady = false
    isDashing = true
    flashButton.Interactable = false
    EnableFlashVFX(true)
    MakePlayerInvincible(true)

    -- APPLY DASH
    local dashDir = horizontal.Unit
    Board:ApplyImpulse(dashDir * dashPower)

    task.delay(DASH_DURATION, function()
        isDashing = false
        MakePlayerInvincible(false)
        EnableFlashVFX(false)
    end)

    -- ===== COOLDOWN UI (same as ApplyDash) =====
    if flashCooldownFiller then
        flashCooldownFiller.Visible = true
        flashCooldownFiller.Size = UDim2.new(1, 0, 1, 0)
    end

    task.spawn(function()
        local step = 0.05
        local timeLeft = DASH_COOLDOWN

        while timeLeft > 0 do
            if flashCooldownFiller then
                local progress = 1 - (timeLeft / DASH_COOLDOWN)
                local sizeProgress = progress * progress
                flashCooldownFiller.Size = UDim2.new(1, 0, 1 - sizeProgress, 0)
            end
            timeLeft = timeLeft - step
            task.wait(step)
        end

        dashReady = true
        if flashCooldownFiller then
            flashCooldownFiller.Visible = false
            flashCooldownFiller.Size = UDim2.new(1, 0, 0, 0)
        end
        flashButton.Interactable = true
    end)
end
-----------------------------------------------------------

----------------- MOVEMENT METHODS ------------------------

local function ReturnAngleBetweenVectors(VectorA, VectorB)
    if VectorA.Magnitude <= FLOATING_ERROR_MARGIN or VectorB.Magnitude <= FLOATING_ERROR_MARGIN then
        return 0
    end

    local dotProduct = VectorA:Dot(VectorB)
    local normalizedDotProduct = math.clamp(dotProduct / (VectorA.Magnitude * VectorB.Magnitude), -1, 1)

    return math.deg(math.acos(normalizedDotProduct))
end

local function ReturnDirectionAndTiltAngle(ReferenceVector, OtherVector, NormalVector)
    NormalVector = NormalVector or Vector3.yAxis

    if ReferenceVector.Magnitude == 0 or OtherVector.Magnitude == 0 then
        return 1, 0
    end

    local crossProduct = ReferenceVector:Cross(OtherVector)
    local direction = crossProduct:Dot(NormalVector) > 0 and 1 or -1

    ReferenceVector = ReferenceVector * Vector3.new(1, 0, 1)
    OtherVector = OtherVector * Vector3.new(1, 0, 1)

    local dotProduct = ReferenceVector:Dot(OtherVector)
    local normalizedDotProduct = math.clamp(dotProduct / (ReferenceVector.Magnitude * OtherVector.Magnitude), -1, 1)

    local angle = math.deg(math.acos(normalizedDotProduct))

    return direction, angle
end

function CalculateMoveDirection()
    local controls = GetControls()
    local inputVector = controls:GetMoveVector()
    if inputVector.Magnitude > 0.1 then
        local goalCFrame = Camera.CFrame * CFrame.new(inputVector.X, 0, inputVector.Z)
        local goalMoveVector = (goalCFrame.Position - Camera.CFrame.Position)
        NewController.MoveVector = (goalMoveVector * Vector3.new(1, 0, 1)).Unit
    else
        NewController.MoveVector = Vector3.zero
        isBraking = false
    end
end

function Lerp(Start, Target, Alpha)
    return Start + (Target - Start) * Alpha
end

function CalculateSpeed(topSpeed)
    local isThrottling = NewController.MoveVector.Magnitude > 0.05
    IsDecelerating = not isThrottling
    NewController.CurrentSpeed = isThrottling and topSpeed or 0

    -- local newTargetSpeed = NewController.MoveVector.Magnitude == 0 and 0 or topSpeed

    -- if NewController.CurrentSpeed ~= newTargetSpeed then
    --     IsDecelerating = newTargetSpeed == 0
    -- end
    -- NewController.CurrentSpeed = newTargetSpeed
end

function ReturnDownhillVector(SurfaceNormal)
    if SurfaceNormal then
        local horizontalVector = SurfaceNormal:Cross(Vector3.yAxis)
        local downhillVector = SurfaceNormal:Cross(horizontalVector)
        if downhillVector.Magnitude >= FLOATING_ERROR_MARGIN then
            return downhillVector.Unit
        end
    end
    return Vector3.zero
end

function GetRaycastResult()
    if not invisiblePart then
        return nil
    end

    local Origin = invisiblePart.Position
    local Direction = Vector3.new(0, -1, 0)
    local CheckingDistance = RayDistance

    local RayParams = RaycastParams.new()
    RayParams.FilterType = Enum.RaycastFilterType.Exclude
    RayParams.FilterDescendantsInstances = {Board, character, invisiblePart}

    local offsetY = Direction * CheckingDistance
    local halfOffset = invisiblePart.Size.Z / 2

    local front = workspace:Raycast(Origin + invisiblePart.CFrame.LookVector * halfOffset, offsetY, RayParams)
    local middle = workspace:Raycast(Origin, offsetY, RayParams)
    local back = workspace:Raycast(Origin - invisiblePart.CFrame.LookVector * halfOffset, offsetY, RayParams)

    return {
        front = front,
        middle = middle,
        back = back
    }
end

local isWallStopped = false
function ApplyVelocity(Acceleration, deltaTimeRender)
    -- ───────────────────────────────────────────────────────────────
    -- 1. GROUND DETECTION  (downhill slope + grounded state)
    -- ───────────────────────────────────────────────────────────────
    local rays = GetRaycastResult()
    local velocityFactor = Acceleration
    if IsDecelerating then
        velocityFactor = grounded and Acceleration * 1.5 or DECELERATION_FACTOR
    end

    local downhillVector = Vector3.zero
    local downhillAngle  = 0
    local middleRayDist  = nil

    if rays then
        local hitCount = 0
        local totalNormal = Vector3.zero
        local totalDistance = 0

        for _, result in pairs(rays) do
            if result then
                hitCount += 1
                totalNormal += result.Normal
                totalDistance += result.Distance
            end
        end
        if hitCount > 0 then
            local averagedNormal = (totalNormal / hitCount)
            if averagedNormal.Magnitude > FLOATING_ERROR_MARGIN then
                averagedNormal = averagedNormal.Unit
            end
            local averagedDistance = totalDistance / hitCount
            grounded = averagedDistance < 0.6
            downhillVector = ReturnDownhillVector(averagedNormal)
            downhillAngle  = ReturnAngleBetweenVectors(averagedNormal, Vector3.yAxis)
        else
            grounded = false
        end
    else
        grounded = false
    end

    -- ───────────────────────────────────────────────────────────────
    -- 2. DOWNHILL SLOPE CONTRIBUTION  (XZ only, no negative-Y push)
    -- ───────────────────────────────────────────────────────────────
    downhillAngle = math.clamp(math.abs(downhillAngle), 0, 45)
    local downhillHorizontal = Vector3.new(downhillVector.X, 0, downhillVector.Z)
    if downhillHorizontal.Magnitude > FLOATING_ERROR_MARGIN then
        downhillHorizontal = downhillHorizontal.Unit
    end
    local downhillContribution =
        downhillHorizontal * (workspace.Gravity / 2) * (downhillAngle / DOWNHILL_SLOPE_ANGLE)

    -- ───────────────────────────────────────────────────────────────
    -- 3. HOVER HEIGHT SPRING-DAMPER  (Y axis)
    -- Maintains a constant TARGET_HOVER_DISTANCE above the ground
    -- surface, regardless of slope direction.
    -- ───────────────────────────────────────────────────────────────
    local correctionY = bodyVelocity.Velocity.Y   -- default: preserve current Y (air)

    -- ───────────────────────────────────────────────────────────────
    -- 4. SMOOTH LANDING  (absorb hard fall-impact on Y)
    --
    -- Fires ONLY when:
    --   • The board just became grounded (near the surface), AND
    --   • The current Y velocity is severely negative (hard fall),
    --     well below what normal slope movement ever produces.
    --
    -- It does NOT fire during:
    --   • Normal jumps  (Y velocity is positive when leaving ground)
    --   • Uphill/downhill travel  (Y velocities stay near 0)
    --   • Regular hover corrections  (correctionY is small)
    --
    -- Mechanism: override correctionY with a strongly damped target
    -- (LANDING_ABSORB fraction of impact), then let the fast Y-lerp
    -- below converge it in a single frame for a crisp, bounce-free land.
    -- ───────────────────────────────────────────────────────────────
    local currentVelY = bodyVelocity.Velocity.Y
    if grounded and currentVelY < LANDING_THRESHOLD then
        -- Absorb the bulk of the impact; allow a tiny residual so the
        -- hover spring can take over cleanly without a hard stop jolt.
        correctionY = 0 --currentVelY * LANDING_ABSORB
    end

    -- ───────────────────────────────────────────────────────────────
    -- 5. WALL AVOIDANCE  (single ray from character → U-turn)
    --
    -- One horizontal ray originates from the character (rootPart) in
    -- the direction the board is currently moving.  If it detects any
    -- BasePart wall within WALL_RAY_LENGTH studs, and the board is
    -- genuinely travelling into that surface (dot < 0), the XZ
    -- velocity is smoothly redirected to the exact OPPOSITE direction.
    --
    -- ───────────────────────────────────────────────────────────────
    local currentXZ       = bodyVelocity.Velocity * Vector3.new(1, 0, 1)
    local collisionActive = false
    local collisionXZ     = currentXZ

    if rootPart and currentXZ.Magnitude > 0.5 then
        local moveDir = currentXZ.Unit

        local wallRay = RaycastParams.new()
        wallRay.FilterType = Enum.RaycastFilterType.Exclude
        wallRay.IgnoreWater = true
        wallRay.FilterDescendantsInstances = {Board, character, invisiblePart}

        local hit = workspace:Raycast(rootPart.Position, moveDir * WALL_RAY_LENGTH, wallRay)

        if hit and hit.Instance and hit.Instance:IsA("BasePart") then
            local flatNormal = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
            if flatNormal.Magnitude > FLOATING_ERROR_MARGIN then
                flatNormal = flatNormal.Unit
                -- Only react when moving INTO the surface (dot < 0).
                if currentXZ:Dot(flatNormal) < 0.5 then
                    collisionActive = true
                end
            end
        end
    end

    -- ───────────────────────────────────────────────────────────────
    -- 6. ASSEMBLE FINAL VELOCITY  (single combination point)
    -- ───────────────────────────────────────────────────────────────
    -- XZ base: player intent + downhill contribution
    local intendedXZ = Vector3.new(
        NewController.MoveVector.X * NewController.CurrentSpeed,
        0,
        NewController.MoveVector.Z * NewController.CurrentSpeed
    ) + downhillContribution

    local finalXZ = intendedXZ
    if collisionActive then
        if intendedXZ.Magnitude > FLOATING_ERROR_MARGIN then
            print("Collision is active")
            -- -- Flip the intended direction 180°
            local reversedDir = -intendedXZ.Unit * 5
            -- Preserve intended speed
            local speed = intendedXZ.Magnitude
            finalXZ = reversedDir * (speed * 2.5)
        end
    end
    local finalVelocity = Vector3.new(finalXZ.X, correctionY, finalXZ.Z)

    -- ───────────────────────────────────────────────────────────────
    -- 7. TILT CALCULATION  (uses combined XZ before write)
    -- ───────────────────────────────────────────────────────────────
    local direction, tiltAngle = ReturnDirectionAndTiltAngle(
        finalVelocity * Vector3.new(1, 0, 1),
        bodyVelocity.Velocity * Vector3.new(1, 0, 1)
    )
    HorizontalTiltAngle = -direction * tiltAngle

    -- ───────────────────────────────────────────────────────────────
    -- 8. SINGLE BODYVELOCITY WRITE
    -- XZ uses the standard acceleration lerp.
    -- Y uses a faster exponential lerp when grounded so hover-spring
    -- and landing corrections converge within the same frame.
    -- ───────────────────────────────────────────────────────────────
    local xzAlpha = deltaTimeRender * velocityFactor
    local yAlpha  = grounded
        and (1 - math.exp(-20 * deltaTimeRender))
        or xzAlpha

    bodyVelocity.Velocity = Vector3.new(
        Lerp(bodyVelocity.Velocity.X, finalVelocity.X, xzAlpha),
        Lerp(bodyVelocity.Velocity.Y, correctionY,     yAlpha),
        Lerp(bodyVelocity.Velocity.Z, finalVelocity.Z, xzAlpha)
    )










    -- local rays = GetRaycastResult()
    -- local velocityFactor = Acceleration
    -- local downhillVector = Vector3.zero
    -- local downhillAngle = 0
    -- local smallestDistance = 0
    -- local currentVelocity = bodyVelocity.Velocity
    -- if rays then
    --     local hits = {}
    --     local totalNormal = Vector3.zero
    --     local totalDistance = 0
    --     for _, result in pairs(rays) do
    --         if result then
    --             table.insert(hits, result)
    --             totalNormal = totalNormal + result.Normal
    --             totalDistance = totalDistance + result.Distance
    --         end
    --     end
    --     if #hits > 0 then
    --         rayHit = true
    --         smallestDistance = totalDistance / #hits
    --         grounded = smallestDistance < 0.6
    --         local averagedNormal = (totalNormal / #hits).Unit
    --         downhillVector = ReturnDownhillVector(averagedNormal)
    --         downhillAngle = ReturnAngleBetweenVectors(averagedNormal, Vector3.yAxis)
    --     else
    --         rayHit = false
    --         grounded = false
    --     end
    -- end
    -- downhillAngle = math.clamp(math.abs(downhillAngle), 0, 90)
    -- local finalVelocity = Vector3.new(NewController.MoveVector.X * NewController.CurrentSpeed, 
    --                                   currentVelocity.Y,
    --     NewController.MoveVector.Z * NewController.CurrentSpeed) + downhillVector * (workspace.Gravity / 2) *
    --                           (downhillAngle / DOWNHILL_SLOPE_ANGLE)

    -- ---------------------------------------------------
    -- -- Smooth falling handling
    -- ---------------------------------------------------
    -- local isFalling = rootPart.AssemblyLinearVelocity.Y < 0
    -- local maxFallingSpeed = -5
    -- local maxDistanceCheck = 3
    -- if isFalling and smallestDistance > 0 and smallestDistance < maxDistanceCheck then
    --     local alpha = 1 - (smallestDistance / maxDistanceCheck)
    --     alpha = math.clamp(alpha, 0, 1)
    --     local targetY = math.max(currentVelocity.Y, maxFallingSpeed)
    --     local smoothY = currentVelocity.Y + (targetY - currentVelocity.Y) * alpha
    --     print("Falling now")
    --     if smallestDistance < maxDistanceCheck then
    --         finalVelocity = Vector3.new(
    --             finalVelocity.X,
    --             smoothY,
    --             finalVelocity.Z
    --         )
    --     end
    -- end
    -- if grounded and isFalling then
    --     finalVelocity = Vector3.new(
    --         finalVelocity.X,
    --         0,
    --         finalVelocity.Z
    --     )
    -- end

    -- local direction, tiltAngle = ReturnDirectionAndTiltAngle(finalVelocity * Vector3.new(1, 0, 1),
    --     bodyVelocity.Velocity * Vector3.new(1, 0, 1))

    -- HorizontalTiltAngle = -direction * tiltAngle
    -- if IsDecelerating then
    --     velocityFactor = rayHit and Acceleration * 1.5 or DECELERATION_FACTOR
    -- end
    -- bodyVelocity.Velocity = currentVelocity:Lerp(finalVelocity, deltaTimeRender * velocityFactor)
end

function ApplyOrientation(deltaTimeRender)
    local rays = GetRaycastResult()
    local BoardCF = Board.CFrame
    local averagedNormal = Vector3.yAxis
    if rays then
        local totalNormal = Vector3.zero
        local hitCount = 0
        for _, result in pairs(rays) do
            if result then
                totalNormal = totalNormal + result.Normal
                hitCount = hitCount + 1
            end
        end
        if hitCount > 0 then
            averagedNormal = (totalNormal / hitCount).Unit
        end
    end
    local velocity = Board.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
    if velocity.Magnitude < 0.01 then
        return
    end
    local LookVector = velocity.Unit
    local RightVector = LookVector:Cross(averagedNormal)
    if RightVector.Magnitude < 0.01 then
        return
    end
    RightVector = RightVector.Unit
    local UpVector = averagedNormal
    local AlignedCFrame = CFrame.fromMatrix(Board.Position, RightVector, UpVector)
    local normalizedTilt = math.clamp(HorizontalTiltAngle, -MAX_HORIZONTAL_TILT, MAX_HORIZONTAL_TILT)
    local alpha = 1 - math.exp(-ORIENTATION_FACTOR * 0.8 * deltaTimeRender)
    local targetCFrame = AlignedCFrame * CFrame.Angles(0, 0, math.rad(normalizedTilt))
    bodyGyro.CFrame = bodyGyro.CFrame:Lerp(targetCFrame, alpha)
end

function UpdateFOV(topSpeed, deltaTimeRender)
    local diff = MAX_FOV - MIN_FOV
    local speedBasedFOV = math.clamp(MIN_FOV + diff * (Board.AssemblyLinearVelocity.Magnitude / topSpeed), MIN_FOV,
        MAX_FOV)
    if isBoosting or isDashing then
        speedBasedFOV = math.min(speedBasedFOV + 10, MAX_FOV + 10)
    end

    Camera.FieldOfView = Lerp(Camera.FieldOfView, speedBasedFOV, deltaTimeRender * FOV_FACTOR)
end

function KeepJumping()
    if spaceHeld and grounded then
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end

function HandleLanding()
    if not rootPart then return end

    local vel = rootPart.AssemblyLinearVelocity
    if vel.Y >= 0 then
        return
    end

    local raycasts = GetRaycastResult()
    if not raycasts then
        return
    end

    local maxFallingSpeed = -5
    local maxDistanceCheck = 1
    
    -- Check all three raycasts
    local closestDistance = math.huge
    if raycasts.front and raycasts.front.Distance then
        closestDistance = math.min(closestDistance, raycasts.front.Distance)
    end
    if raycasts.middle and raycasts.middle.Distance then
        closestDistance = math.min(closestDistance, raycasts.middle.Distance)
    end
    if raycasts.back and raycasts.back.Distance then
        closestDistance = math.min(closestDistance, raycasts.back.Distance)
    end
    
    if closestDistance <= maxDistanceCheck and rootPart then
        local newY = math.max(vel.Y, maxFallingSpeed)
        bodyVelocity.Velocity = Vector3.new(vel.X, newY, vel.Z)
        --rootPart.AssemblyLinearVelocity = Vector3.new(vel.X, newY, vel.Z)
    end















    -- if not rootPart then return end

    -- local vel = rootPart.AssemblyLinearVelocity
    -- if vel.Y >= 0 then
    --     return
    -- end

    -- local raycast = GetRaycastResult()
    -- if not raycast then
    --     return
    -- end

    -- local maxFallingSpeed = -5
    -- local maxDistanceCheck = 1
    -- if raycast.Distance <= maxDistanceCheck and rootPart then
    --     local newY = math.max(vel.Y, maxFallingSpeed)
    --     rootPart.AssemblyLinearVelocity = Vector3.new(vel.X, newY, vel.Z)
    -- end
end

function UpdateFlyBar(dt)
    local state = humanoid:GetState()

    -- Flying → drain
    if isFlying and spaceHeld and canFly and state == Enum.HumanoidStateType.Freefall then
        flyEnergy = flyEnergy - DRAIN_RATE * dt
        flyEnergy = math.clamp(flyEnergy, 0, MAX_FLY_ENERGY)
        if flyEnergy <= 0 then
            isFlying = false
        end

        -- Grounded → refill
    elseif state == Enum.HumanoidStateType.Running or state == Enum.HumanoidStateType.Landed or state ==
        Enum.HumanoidStateType.Physics then

        flyEnergy = flyEnergy + REFILL_RATE * dt
        flyEnergy = math.clamp(flyEnergy, 0, MAX_FLY_ENERGY)
    end
    local ratio = flyEnergy / MAX_FLY_ENERGY
    if ProductsController.flybar then
        ProductsController.flybar.Size = ProductsController.flybar.Size:Lerp(UDim2.fromScale(1, ratio), 0.2)
    end
end
-----------------------------------------------------------

-- PLAYER LIFECYCLE
local function HideCharacter(char)
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Transparency = 1
            obj.CastShadow = false
        elseif obj:IsA("Decal") then
            obj.Transparency = 1
        end
    end
end

local function SetTrail(trailColor)
    if Trail then
        Trail.Color = ColorSequence.new(trailColor)
    end
end

local function ApplyEquippedTrail()
    GearService:GetEquippedTrail():andThen(function(trailName)
        print("Trail: ", trailName)
        if not Trail then
            return
        end

        if not trailName then
            print("No trail equipped.")
            Trail.Enabled = false
            return
        end

        local config = TrailsConfig.GetConfig(trailName)
        if not config then
            warn("Invalid trail config:", trailName)
            Trail.Enabled = false
            return
        end
        Trail.Enabled = true
        SetTrail(config.Color)
        print("Trail applied:", trailName)
    end)
end

local function ResetStates()
    print("Reset states called")
    character = nil
    humanoid = nil
    rootPart = nil
    Board = nil
    bodyGyro = nil
    controls = nil
    acceleration = 0
    topSpeed = 0
    jumpPower = 0
    NewController.SpeedVar = 0
    NewController.CurrentSpeed = 0
    flyEnergy = 0
    grounded = false
    isHoverboardInitialized = false
    boostReady = true
    dashReady = true
    isDashing = false
    spaceHeld = false
end

local function InitializeHoverboard()
    if character then
        print("Initializing hoverboard for character.")
        local hoverboardPart = character:FindFirstChild("Hoverboard")
        if hoverboardPart then
            -- Get hoverboard data from server
            HoverboardService:GetHoverboardData():andThen(function(data)
                if data then
                    print("Initializing hoverboard:", data.Name)
                    NewController:SetActiveConfig(data.Name)
                else
                    -- Fallback to default
                    print("No hoverboard data, using default")
                    NewController:SetActiveConfig("Hoverboard1")
                end
            end):catch(function(err)
                warn("Failed to get hoverboard data:", err)
                NewController:SetActiveConfig("Hoverboard1")
            end)
        end
    end
end

function NewController:HumanoidSetup(jumpPower)
    humanoid.UseJumpPower = true
    humanoid.JumpPower = jumpPower
    humanoid.BreakJointsOnDeath = false
end

function NewController:SetActiveConfig(boardName)
    if isHoverboardInitialized then
        print("Hoverboard: Hoverboard already initialized, skipping SetActiveHoverboard")
        return
    end
    local config = HoverboardData.GetConfig(boardName)
    if not config then
        warn("Hoverboard: Could not find hoverboard config for " .. tostring(boardName))
        return
    end
    self.ActiveConfig = config
    print("Hoverboard: Active config: ", self.ActiveConfig)
    Board = character:WaitForChild("Hoverboard"):WaitForChild("PrimaryPart")
    invisiblePart = Board.Parent:WaitForChild("Invisible")
    Trail = Board:WaitForChild("Trail")
    ApplyEquippedTrail()
    isHoverboardInitialized = true
    self:StartHoverboard(config)
end

function NewController:StartHoverboard(config)
    print("StartHoverboard called")
    acceleration = config.Acceleration or ACCELERATION
    topSpeed = config.TopSpeed or MAX_SPEED
    jumpPower = config.JumpPower or JUMP_POWER
    print("Hoverboard: Got acceleration and top speed: ", acceleration, " ", topSpeed)

    InitBodyMovers()
    self:HumanoidSetup(jumpPower)
    RefreshBoostGUI()
    RefreshFlashGUI()
    CloneVFX()

    if runningConnection then
        runningConnection:Disconnect()
    end
    runningConnection = RunService.PreRender:Connect(function(dt)
        CalculateMoveDirection()
        CalculateSpeed(topSpeed)
        ApplyVelocity(acceleration, dt)
        ApplyOrientation(dt)
        --WallDetection(dt)
        UpdateFOV(topSpeed, dt)
        KeepJumping()
        --HandleLanding()
        UpdateFlyBar(dt)

        if speedGUI and speedLabel and speedFrame then
            UpdateSpeedGUI(topSpeed)
        end
    end)
end

function InputListeners()
    UserInputService.InputBegan:Connect(function(Input, gameProcessedEvent)
        if gameProcessedEvent then
            return
        end

        if Input.UserInputType == Enum.UserInputType.Keyboard then
            if Input.KeyCode == Enum.KeyCode.Q then
                print("Hoverboard: Boost requested.")
                ApplyBoost(BOOST_DURATION, BOOST_AMOUNT)
            end
            if Input.KeyCode == Enum.KeyCode.F then
                print("Hoverboard: Flash requested.")
                -- ApplyDash(DASH_AMOUNT, DASH_DURATION, DASH_DISTANCE)
                Dash(DASH_AMOUNT)
            end
            if Input.KeyCode == Enum.KeyCode.Space then
                spaceHeld = true
                local state = humanoid:GetState()

                -- Double jump
                if totalJumps < 2 and canDoubleJump then
                    totalJumps = totalJumps + 1
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    return
                end

                -- Single jump
                if grounded then
                    humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
                    totalJumps = 1
                    return
                end
            end
        end
    end)
    UserInputService.JumpRequest:Connect(function()
        -- Fly
        if not canFly then
            return
        end
        if flyEnergy <= 0 then
            return
        end
        if humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
            return
        end

        isFlying = true
        humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
    end)
    UserInputService.InputEnded:Connect(function(Input, GameProcessed)
        if GameProcessed then
            return
        end

        if Input.UserInputType == Enum.UserInputType.Keyboard then
            if Input.KeyCode == Enum.KeyCode.Space then
                spaceHeld = false
                isFlying = false
            end
        end
    end)
    boostButton.MouseButton1Click:Connect(function()
        print("Hoverboard: Boost requested.")
        ApplyBoost(BOOST_DURATION, BOOST_AMOUNT)
    end)
    flashButton.MouseButton1Click:Connect(function()
        print("Hoverboard: Flash requested.")
        -- ApplyDash(DASH_AMOUNT, DASH_DURATION, DASH_DISTANCE)
        Dash(DASH_AMOUNT)
    end)
end

function HandleHumanoidStates()
    humanoid.StateChanged:Connect(function(oldState, newState)
        if newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running then
            humanoid:ChangeState(Enum.HumanoidStateType.Physics)
            totalJumps = 0
            canDoubleJump = false
            canFly = false
            isFlying = false
        end

        -- Handle double jump
        if oldState == Enum.HumanoidStateType.Jumping and ProductsController.HasDoubleJump and
            not ProductsController.HasFly and totalJumps == 1 and newState == Enum.HumanoidStateType.Freefall then
            canDoubleJump = true
        end

        -- Handle fly
        if oldState == Enum.HumanoidStateType.Jumping and ProductsController.HasFly and newState ==
            Enum.HumanoidStateType.Freefall and totalJumps == 1 then
            canFly = true
        end

    end)
end

function NewController:OnCharacterAdded(char)
    HoverboardService = Knit.GetService("HoverboardService")
    GearService = Knit.GetService("GearService")
    ProductsService = Knit.GetService("ProductsService")
    ProductsController = Knit.GetController("ProductsController")

    character = char
    humanoid = char:WaitForChild("Humanoid")
    humanoid.AutoRotate = false
    HandleHumanoidStates()
    humanoid:ChangeState(Enum.HumanoidStateType.Physics)

    -- Disable all humanoid animations
    local animator = humanoid:FindFirstChildOfClass("Animator")
    if animator then
        animator:Destroy()
    end
    -- Also remove Animate script if present (extra safety)
    local animateScript = character:FindFirstChild("Animate")
    if animateScript then
        animateScript:Destroy()
    end
    rootPart = char:WaitForChild("HumanoidRootPart")
    rootPart.CastShadow = false
    motor = rootPart:WaitForChild("HoverboardMotor")
    BASE_C0 = motor.C0
    BASE_C1 = motor.C1
    InputListeners()
    InitializeHoverboard()
end

function NewController:OnCharacterRemoving()
    if runningConnection then
        runningConnection:Disconnect()
        runningConnection = nil
    end
    ResetStates()
end

function NewController:OnPlayerAdded(plr)
    if plr ~= player then
        return
    end
    plr.CharacterAdded:Connect(function()
        self:OnCharacterAdded(plr.Character or plr.CharacterAdded:Wait())
    end)
    plr.CharacterRemoving:Connect(self.OnCharacterRemoving)
    if plr.Character then
        self:OnCharacterAdded(plr.Character or plr.CharacterAdded:Wait())
    end
end

-- [External Modifier Functions]		------
function NewController:ApplyAssist(ForceVector)
    bodyVelocity.Velocity = bodyVelocity.Velocity + ForceVector
    -- rootPart.AssemblyLinearVelocity += ForceVector	--Added
end

function NewController:ApplyJump(JumpPower)
    local v = Board.AssemblyLinearVelocity
    Board.AssemblyLinearVelocity = Vector3.new(v.X, JumpPower, v.Z)
end

function NewController:Slow()
    bodyVelocity.Velocity = Vector3.zero
    local originalAcceleration = acceleration

    acceleration = acceleration * 0.1
    task.delay(0.2, function()
        acceleration = originalAcceleration
    end)
end

------------------------------------------------

function NewController:BindGear()
    HoverboardService.HoverboardChanged:Connect(function(boardName)
        print("HoverboardChanged event received:", boardName)
        InitializeHoverboard()
    end)
    HoverboardService.HoverboardSpawned:Connect(function()
        print("HoverboardSpawned event received")
        InitializeHoverboard()
    end)
    HoverboardService.HoverboardRemoved:Connect(function()
        isHoverboardInitialized = false
    end)
    GearService.TrailEquipped:Connect(function(trailName)
        print("EquipTrail event received")
        local trailConfig = TrailsConfig.GetConfig(trailName)
        if not trailConfig then
            return
        end
        Trail.Enabled = true
        SetTrail(trailConfig.Color)
    end)
    GearService.TrailUnequipped:Connect(function()
        Trail.Enabled = false
    end)
    HoverboardService.ControlSignal:Connect(function(action)
        local ctrl = GetControls()
        if action == "Disable" then
            ctrl:Disable()
        elseif action == "Enable" then
            ctrl:Enable()
        end
    end)
end

function NewController:KnitStart()
    print("NewController started")
    self:OnPlayerAdded(player)
    self:BindGear()
end

return NewController
