local spritesheet = require("spritesheet")

-- Global transparency color (RGB values 0-255)
TRANSPARENCY_COLOR = {186, 254, 202}

-- Game state
local gameState = "title"  -- "title" or "playing"
local timer = 999
local timerAccumulator = 0  -- Accumulator for timer countdown (10 per second = every 0.1 seconds)

-- Car position and movement
local carX = 355
local carY = 530
local carSpeed = 0  -- pixels per second
local carAccelerationSpeed = 160  -- pixels per second (640 height / 4 seconds = 160)

-- Car gear system
local carGear = "low"  -- "low" or "high"

-- Gamepad
local gamepad = nil
local previousZAxis = 0  -- Track previous Z-axis value to detect movement

-- Game data (saved to file)
local gameData = {
    highScore = 0
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
            if data and data.highScore then
                gameData.highScore = data.highScore or 0
            end
        end
    else
        -- File doesn't exist, use defaults (already set to 0)
        saveGameData()
    end
end

-- Save game data to file
function saveGameData()
    local dataString = string.format("return {\n    highScore = %d\n}", gameData.highScore)
    love.filesystem.write(saveFileName, dataString)
end

function love.load()
    -- Load saved game data
    loadGameData()
    
    -- Detect gamepad
    local joysticks = love.joystick.getJoysticks()
    if #joysticks > 0 then
        gamepad = joysticks[1]
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
end

function startNewGame()
    gameState = "playing"
    timer = 999
    timerAccumulator = 0
    
    -- Reset car position
    carX = 355
    carY = 530
    carSpeed = 0
    
    -- Reset gear to low
    carGear = "low"
    
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
        -- Check for gamepad input using Z axis (axis 3)
        -- Z axis going right (increasing/positive) = left trigger = accelerate
        -- Z axis going left (decreasing/negative) = right trigger
        local accelerationValue = 0
        if gamepad then
            -- EXPERIMENT: Test button 1 for acceleration
            if gamepad:isDown(1) then
                accelerationValue = 1.0  -- Full speed for button test
            else
                -- Get Z axis (typically axis 3)
                local zAxis = gamepad:getAxis(3)
                
                -- Z axis typically ranges from -1 to 1
                -- Positive values (going right) = left trigger = accelerate
                -- Negative values (going left) = right trigger = brake/reverse (not used for now)
                if zAxis > 0 then
                    -- Normalize from 0-1 range for acceleration (positive Z axis values)
                    accelerationValue = zAxis
                end
            end
        end
        
        -- Accelerate car based on Z axis (positive values) or button 1
        if accelerationValue > 0.1 then  -- Dead zone threshold
            carSpeed = carAccelerationSpeed * accelerationValue
        else
            carSpeed = 0
        end
        
        -- Update car position (move forward = decrease Y position)
        carY = carY - (carSpeed * dt)
        
        -- Keep car within screen bounds
        local carHeight = 52
        if carY < 0 then
            carY = 0
        elseif carY > love.graphics.getHeight() - carHeight then
            carY = love.graphics.getHeight() - carHeight
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
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()

    -- Set text color (white)
    love.graphics.setColor(1, 1, 1)

    if gameState == "title" then
        -- Draw title screen
        love.graphics.setFont(titleFont)
        -- Center text horizontally, position higher than center (about 35% from top)
        local textWidth = titleFont:getWidth(titleText)
        local textHeight = titleFont:getHeight()

        love.graphics.print(
            titleText,
            (width - textWidth) / 2,
            height * 0.35 - textHeight / 2
        )
    elseif gameState == "playing" then
        -- Draw game screen
        -- Draw background image
        love.graphics.draw(backgroundImage, 0, 0)
        
        -- Display timer at the top center
        local timerText = tostring(timer)
        love.graphics.setFont(timerFont)
        local timerWidth = timerFont:getWidth(timerText)
        
        love.graphics.print(
            timerText,
            (width - timerWidth) / 2,
            20  -- 20px from top
        )
        
        -- Draw the car sprite at current position
        carSprites:draw(1, carX, carY)
    end
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == "space" then
        if gameState == "title" then
            startNewGame()
        end
    end
end
