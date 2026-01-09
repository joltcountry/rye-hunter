local spritesheet = require("spritesheet")

-- Global transparency color (RGB values 0-255)
TRANSPARENCY_COLOR = {186, 254, 202}

-- Game state
local gameState = "title"  -- "title" or "playing"
local timer = 999
local timerAccumulator = 0  -- Accumulator for timer countdown (10 per second = every 0.1 seconds)

-- Game rendering scale
local BASE_WIDTH = 480
local BASE_HEIGHT = 640
local gameCanvas = nil
local scaleX, scaleY = 1, 1
local offsetX, offsetY = 0, 0

-- Car position and movement
local carX = 355
local carY = 530
local carStartY = 530  -- Starting Y position
local carSpeed = 0  -- pixels per second
local carAccelerationSpeed = 128  -- pixels per second (reduced by 20% from 160)

-- Car gear system
local carGear = "low"  -- "low" or "high"

-- Machine gun
local isFiring = false  -- Whether machine gun is currently firing

-- Debug: Track which axis is active for acceleration
local activeAxis = nil  -- Will be 3, 5, or 6 when active

-- Gamepad
local gamepad = nil
local previousZAxis = 0  -- Track previous Z-axis value to detect movement
local debugCounter = 0  -- Counter to throttle debug output

-- Game data (saved to file)
local gameData = {
    highScore = 0,
    windowWidth = 480,  -- Default window width
    windowHeight = 640,  -- Default window height
    muted = false  -- Sound mute state
}

-- File path for saved data
local saveFileName = "gamedata.lua"

-- Load game data from file
function loadGameData()
    if love.filesystem.getInfo(saveFileName) then
        -- File exists, load it
        local success, chunk = pcall(love.filesystem.load, saveFileName)
        if success and chunk then
            local data = chunk()
            if data then
                if data.highScore then
                    gameData.highScore = data.highScore or 0
                end
                if data.windowWidth then
                    gameData.windowWidth = data.windowWidth or 480
                end
                if data.windowHeight then
                    gameData.windowHeight = data.windowHeight or 640
                end
                if data.muted ~= nil then
                    gameData.muted = data.muted
                end
            end
        end
    else
        -- File doesn't exist, use defaults and save
        saveGameData()
    end
    
    -- Apply mute state
    if gameData.muted then
        love.audio.setVolume(0)
    else
        love.audio.setVolume(1)
    end
end

-- Save game data to file
function saveGameData()
    local mutedStr = gameData.muted and "true" or "false"
    local dataString = string.format("return {\n    highScore = %d,\n    windowWidth = %d,\n    windowHeight = %d,\n    muted = %s\n}", 
                                     gameData.highScore, gameData.windowWidth, gameData.windowHeight, mutedStr)
    love.filesystem.write(saveFileName, dataString)
end

function love.load()
    -- Load saved game data
    loadGameData()
    
    -- Restore saved window size (if different from default)
    if gameData.windowWidth and gameData.windowHeight then
        local currentWidth, currentHeight = love.window.getMode()
        if currentWidth ~= gameData.windowWidth or currentHeight ~= gameData.windowHeight then
            love.window.setMode(gameData.windowWidth, gameData.windowHeight, {resizable = true})
        end
    end
    
    -- Detect gamepad
    local joysticks = love.joystick.getJoysticks()
    if #joysticks > 0 then
        gamepad = joysticks[1]
        
        -- Debug: Print gamepad information
        print("=== Gamepad Debug Info ===")
        print("Gamepad Name: " .. tostring(gamepad:getName()))
        print("Axis Count: " .. tostring(gamepad:getAxisCount()))
        
        -- Print all axis values
        local axisCount = gamepad:getAxisCount()
        for i = 1, axisCount do
            local axisValue = gamepad:getAxis(i)
            print("Axis " .. i .. ": " .. tostring(axisValue))
        end
        print("==========================")
    else
        print("No gamepad detected!")
    end
    
    -- Set background color (black)
    love.graphics.setBackgroundColor(0, 0, 0)

    -- Load arcade-style font
    titleFont = love.graphics.newFont("fonts/spy-hunter-arcade.ttf", 32)
    love.graphics.setFont(titleFont)
    
    -- Load timer font (35% smaller than title font: 32 * 0.65 = 20.8, rounded to 21)
    timerFont = love.graphics.newFont("fonts/spy-hunter-arcade.ttf", 21)

    -- Title text
    titleText = "RYE HUNTER"
    
    -- Load theme music (but don't play it yet - it will play when game starts)
    themeMusic = love.audio.newSource("sound/Theme to Peter Gunn.mp3", "stream")
    themeMusic:setLooping(true)
    
    -- Load car sprite sheet
    -- Car sprite: 42px wide, remaining 4 sprites: 47px each (188px / 4)
    -- Total: 230x52, sprite height: 52px
    carSprites = spritesheet.loadCustom(
        "images/car01.png",
        {42, 47, 47, 47, 47},  -- sprite widths
        52,                      -- sprite height
        0,                       -- no margin
        TRANSPARENCY_COLOR      -- apply transparency color
    )
    
    -- Load background image
    backgroundImage = love.graphics.newImage("images/background01.png")
    
    -- Create game canvas at base resolution
    gameCanvas = love.graphics.newCanvas(BASE_WIDTH, BASE_HEIGHT)
    
    -- Load machine gun image with transparency
    local machineGunData = love.image.newImageData("images/machineGun01.png")
    -- Apply transparency color to machine gun image
    local transR = TRANSPARENCY_COLOR[1] / 255
    local transG = TRANSPARENCY_COLOR[2] / 255
    local transB = TRANSPARENCY_COLOR[3] / 255
    local tolerance = 0.01
    for y = 0, machineGunData:getHeight() - 1 do
        for x = 0, machineGunData:getWidth() - 1 do
            local r, g, b, a = machineGunData:getPixel(x, y)
            if math.abs(r - transR) < tolerance and
               math.abs(g - transG) < tolerance and
               math.abs(b - transB) < tolerance then
                machineGunData:setPixel(x, y, r, g, b, 0)
            end
        end
    end
    machineGunImage = love.graphics.newImage(machineGunData)
    
    -- Initialize scale
    updateScale(love.graphics.getWidth(), love.graphics.getHeight())
end

-- Update scale and offset based on window size
function updateScale(windowWidth, windowHeight)
    -- Calculate scale to fit window while maintaining aspect ratio
    scaleX = windowWidth / BASE_WIDTH
    scaleY = windowHeight / BASE_HEIGHT
    scaleX = math.min(scaleX, scaleY)  -- Use smaller scale to maintain aspect ratio
    scaleY = scaleX
    
    -- Calculate offset to center the scaled game canvas
    offsetX = (windowWidth - BASE_WIDTH * scaleX) / 2
    offsetY = (windowHeight - BASE_HEIGHT * scaleY) / 2
end

function startNewGame()
    gameState = "playing"
    timer = 999
    timerAccumulator = 0
    
    -- Reset car position
    carX = 355
    carY = 530
    carStartY = 530  -- Reset starting position
    carSpeed = 0
    
    -- Reset gear to low
    carGear = "low"
    
    -- Reset machine gun state
    isFiring = false
    
    -- Start playing the theme music
    themeMusic:play()
end

function love.update(dt)
    -- Check for Z-axis movement to start game from title screen
    if gameState == "title" and gamepad then
        local zAxis = gamepad:getAxis(3)
        -- Check if Z-axis has moved from near-zero to any significant value
        if math.abs(previousZAxis) < 0.1 and math.abs(zAxis) > 0.1 then
            startNewGame()
        end
        previousZAxis = zAxis
    end
    
    if gameState == "playing" then
        -- Acceleration: Left trigger - uses axis 5
        -- NOTE: Axis 4 is reserved for steering (right stick)
        local accelerationValue = 0
        activeAxis = nil  -- Reset active axis
        if gamepad then
            -- Get axis 5 (left trigger for this gamepad)
            local axis5 = gamepad:getAxis(5)
            
            -- Axis 5 typically ranges from -1 to 1
            -- Positive values = left trigger pressed = accelerate forward
            -- Threshold of 0.15 to avoid drift from neutral position
            if axis5 > 0.15 then
                accelerationValue = axis5
                activeAxis = 5
            end
        end
        
        -- Calculate car speed based on acceleration
        if accelerationValue > 0.1 then
            carSpeed = carAccelerationSpeed * accelerationValue
        else
            carSpeed = 0
        end
        
        -- Machine gun firing: Button 2 fires the machine gun
        isFiring = false  -- Reset firing state
        if gamepad then
            if gamepad:isDown(2) then
                isFiring = true
            end
        end
        
        -- Steering: Right analog stick controls left/right movement
        -- Steering only works when accelerating - don't check stick unless accelerating
        local steeringValue = 0
        if gamepad and accelerationValue > 0.1 then
            -- Read axis 3 (right stick X-axis for left/right movement)
            -- Axis 4 was the Y-axis (up/down), axis 3 should be the X-axis (left/right)
            local rightStickX = gamepad:getAxis(3)
            
            -- Higher dead zone threshold (0.2) to prevent accidental steering from neutral position
            if math.abs(rightStickX) > 0.2 then
                steeringValue = rightStickX  -- Direct mapping: stick right = steer right, stick left = steer left
                activeAxis = 3
            end
        end
        
        -- Update car position
        -- Move forward = decrease Y position (based on speed)
        carY = carY - (carSpeed * dt)
        
        -- Move left/right based on steering (only when accelerating)
        -- steeringValue is only non-zero when accelerating, so this is safe
        local steeringSpeed = 320  -- pixels per second for steering (reduced by 20% from 400)
        carX = carX + (steeringValue * steeringSpeed * dt)
        
        -- Keep car within screen bounds (using base resolution)
        local carHeight = 52
        local carWidth = 42
        
        -- Apply horizontal screen bounds (base width)
        if carX < 0 then
            carX = 0
        elseif carX > BASE_WIDTH - carWidth then
            carX = BASE_WIDTH - carWidth
        end
        
        -- Apply vertical screen bounds (base height)
        if carY < 0 then
            carY = 0
        elseif carY > BASE_HEIGHT - carHeight then
            carY = BASE_HEIGHT - carHeight
        end
        
        -- Keep car within horizontal screen bounds
        if carX < 0 then
            carX = 0
        elseif carX > love.graphics.getWidth() - carWidth then
            carX = love.graphics.getWidth() - carWidth
        end
        
        -- Update timer: count down at 10 per second (every 0.1 seconds)
        timerAccumulator = timerAccumulator + dt
        while timerAccumulator >= 0.1 and timer > 0 do
            timer = timer - 1
            timerAccumulator = timerAccumulator - 0.1
        end
        
        -- Prevent timer from going below 0
        if timer < 0 then
            timer = 0
        end
    end
end

function love.draw()
    -- Get window dimensions
    local windowWidth = love.graphics.getWidth()
    local windowHeight = love.graphics.getHeight()
    
    -- Update scale in case window was resized
    updateScale(windowWidth, windowHeight)

    -- Set canvas as render target
    love.graphics.setCanvas(gameCanvas)
    love.graphics.clear()
    
    -- Set text color (white)
    love.graphics.setColor(1, 1, 1)

    if gameState == "title" then
        -- Draw title screen to canvas
        love.graphics.setFont(titleFont)
        -- Center text horizontally, position higher than center (about 35% from top)
        local textWidth = titleFont:getWidth(titleText)
        local textHeight = titleFont:getHeight()

        love.graphics.print(
            titleText,
            (BASE_WIDTH - textWidth) / 2,
            BASE_HEIGHT * 0.35 - textHeight / 2
        )
    elseif gameState == "playing" then
        -- Draw game screen to canvas
        -- Draw background image
        love.graphics.draw(backgroundImage, 0, 0)
        
        -- Display timer at the top center
        local timerText = tostring(timer)
        love.graphics.setFont(timerFont)
        local timerWidth = timerFont:getWidth(timerText)
        local timerX = (BASE_WIDTH - timerWidth) / 2
        local timerY = 20  -- 20px from top
        
        love.graphics.print(
            timerText,
            timerX,
            timerY
        )
        
        -- Display active axis debug number on the right side
        -- Same Y position as timer, equidistant from timer's right edge and screen edge
        if activeAxis then
            local axisText = "Axis: " .. tostring(activeAxis)
            local axisTextWidth = timerFont:getWidth(axisText)
            local timerRightEdge = timerX + timerWidth
            local screenRightEdge = BASE_WIDTH
            local distance = (screenRightEdge - timerRightEdge) / 2  -- Equidistant spacing
            local axisX = timerRightEdge + distance - (axisTextWidth / 2)  -- Center the axis text in the space
            
            love.graphics.print(
                axisText,
                axisX,
                timerY
            )
        end
        
        -- Draw the car sprite at current position
        carSprites:draw(1, carX, carY)
        
        -- Draw machine gun when firing (above the topmost pixel of the car)
        -- Machine gun dimensions: 10px wide x 26px tall
        if isFiring then
            local machineGunWidth = machineGunImage:getWidth()  -- 10px
            local machineGunHeight = machineGunImage:getHeight()  -- 26px
            -- Position machine gun centered horizontally on car, above the car's top edge
            local machineGunX = carX + (42 / 2) - (machineGunWidth / 2)  -- Center on car (car width is 42)
            local machineGunY = carY - machineGunHeight  -- Above the car's top edge (26px above)
            love.graphics.draw(machineGunImage, machineGunX, machineGunY)
        end
    end
    
    -- Reset canvas (draw to screen)
    love.graphics.setCanvas()
    
    -- Draw the scaled canvas to the window
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(gameCanvas, offsetX, offsetY, 0, scaleX, scaleY)
end

function love.resize(width, height)
    -- Save window size when user resizes the window
    gameData.windowWidth = width
    gameData.windowHeight = height
    saveGameData()
    
    -- Update scale for new window size
    updateScale(width, height)
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "space" then
        if gameState == "title" then
            startNewGame()
        end
    elseif key == "s" then
        -- Toggle mute/unmute (works for both lowercase and uppercase 's')
        gameData.muted = not gameData.muted
        if gameData.muted then
            love.audio.setVolume(0)
        else
            love.audio.setVolume(1)
        end
        saveGameData()  -- Save mute preference
    end
end
