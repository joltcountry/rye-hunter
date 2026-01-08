function love.load()
    -- Set background color (black)
    love.graphics.setBackgroundColor(0, 0, 0)

    -- Load arcade-style font
    titleFont = love.graphics.newFont("fonts/spy-hunter-arcade.ttf", 32)
    love.graphics.setFont(titleFont)

    -- Title text
    titleText = "SPY HUNTER"
end

function love.update(dt)
    -- Nothing to update yet (title screen)
end

function love.draw()
    -- Get window dimensions
    local width = love.graphics.getWidth()
    local height = love.graphics.getHeight()

    -- Set text color (white)
    love.graphics.setColor(1, 1, 1)

    -- Center text horizontally and vertically
    local textWidth = titleFont:getWidth(titleText)
    local textHeight = titleFont:getHeight()

    love.graphics.print(
        titleText,
        (width - textWidth) / 2,
        (height - textHeight) / 2
    )
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
