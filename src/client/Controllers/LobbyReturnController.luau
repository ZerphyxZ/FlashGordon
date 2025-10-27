-- LobbyReturnController.luau
-- Teleport the local player to Workspace.SpawnLocation when pressing:
-- StarterGui/MainGui/LobbyRetureFrame/LobbyRetureButton
-- Knit controller; no pcall; resilient to GUI re-creation.

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages:WaitForChild("Knit"))
local Controller = Knit.CreateController { Name = "LobbyReturnController" }

local LOCAL_PLAYER = Players.LocalPlayer

-- Config
local BUTTON_PATH = { "MainGui", "LobbyRetureFrame", "LobbyRetureButton" }
local UPWARD_OFFSET = Vector3.new(0, 5, 0) -- spawn a little above pad

-- internal
local _bound = false

-- Try to find the button inside PlayerGui/MainGui even if re-created
local function findButton(): TextButton?
    local pg = LOCAL_PLAYER:FindFirstChild("PlayerGui")
    if not pg then return nil end

    local node: Instance? = pg:FindFirstChild(BUTTON_PATH[1])
    for i = 2, #BUTTON_PATH do
        if not node then return nil end
        node = node:FindFirstChild(BUTTON_PATH[i])
    end
    if node and node:IsA("TextButton") then
        return node
    end
    return nil
end

-- Teleport to Workspace.SpawnLocation (fallback to StartSpawn if present)
local function teleportToSpawn()
    local character = LOCAL_PLAYER.Character or LOCAL_PLAYER.CharacterAdded:Wait()
    local hrp = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not (hrp and humanoid) then return end

    -- Prefer standard Roblox SpawnLocation named "SpawnLocation"
    local spawnPart = Workspace:FindFirstChild("SpawnLocation")
    -- Optional fallback if you also keep a StartSpawn part in your place
    if not (spawnPart and spawnPart:IsA("BasePart")) then
        local alt = Workspace:FindFirstChild("StartSpawn")
        if alt and alt:IsA("BasePart") then
            spawnPart = alt
        end
    end
    if not (spawnPart and spawnPart:IsA("BasePart")) then
        warn("[LobbyReturnController] No SpawnLocation or StartSpawn found in Workspace.")
        return
    end

    -- Zero motion for a clean teleport
    if hrp.AssemblyLinearVelocity then hrp.AssemblyLinearVelocity = Vector3.zero end
    if hrp.AssemblyAngularVelocity then hrp.AssemblyAngularVelocity = Vector3.zero end

    -- Nudge up to avoid clipping into the pad
    local destCFrame = spawnPart.CFrame + UPWARD_OFFSET

    -- Briefly disable auto-rotate to avoid camera/rotation hitches, then restore
    local oldAuto = humanoid.AutoRotate
    humanoid.AutoRotate = false
    hrp.CFrame = destCFrame
    humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
    task.delay(0.1, function()
        if humanoid and humanoid.Parent then
            humanoid.AutoRotate = oldAuto
        end
    end)

    print("[LobbyReturnController] Teleported to spawn:", spawnPart:GetFullName())
end

-- Bind the click once; rebind safely on GUI recreation
local function bindButtonIfPresent()
    if _bound then return end
    local btn = findButton()
    if not btn then return end

    btn.MouseButton1Click:Connect(function()
        teleportToSpawn()
    end)
    _bound = true
    print("[LobbyReturnController] Bound LobbyRetureButton.")
end

function Controller:KnitStart()
    -- Initial bind (if GUI is already present)
    bindButtonIfPresent()

    -- Rebind when MainGui gets re-created in PlayerGui
    local pg = LOCAL_PLAYER:FindFirstChild("PlayerGui")
    if pg then
        pg.ChildAdded:Connect(function(child)
            if child.Name == "MainGui" then
                -- Allow its children to populate
                task.delay(0.05, function()
                    _bound = false
                    bindButtonIfPresent()
                end)
            end
        end)
    else
        -- If PlayerGui isn't present yet, wait and then attach the watcher
        task.spawn(function()
            local gui = LOCAL_PLAYER:WaitForChild("PlayerGui")
            gui.ChildAdded:Connect(function(child)
                if child.Name == "MainGui" then
                    task.delay(0.05, function()
                        _bound = false
                        bindButtonIfPresent()
                    end)
                end
            end)
            -- Also try to bind immediately after we obtained PlayerGui
            task.delay(0.05, function()
                _bound = false
                bindButtonIfPresent()
            end)
        end)
    end

    -- Also attempt a couple of delayed binds to cover streaming/UI delays
    task.delay(0.25, function() _bound = false; bindButtonIfPresent() end)
    task.delay(1.0,  function() _bound = false; bindButtonIfPresent() end)
end

return Controller
