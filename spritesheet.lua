-- Sprite Sheet Utility
-- Helper functions for working with sprite sheets

local Spritesheet = {}

-- Helper function to apply transparency color to an image
-- @param imagePath: path to the image file
-- @param transparencyColor: table with {R, G, B} values (0-255)
-- @return: Love2D Image object with transparency applied
local function applyTransparency(imagePath, transparencyColor)
    if not transparencyColor then
        -- No transparency color specified, load normally
        return love.graphics.newImage(imagePath)
    end
    
    -- Load image as ImageData
    local imageData = love.image.newImageData(imagePath)
    local width = imageData:getWidth()
    local height = imageData:getHeight()
    
    -- Convert RGB values to 0-1 range for comparison
    local transR = transparencyColor[1] / 255
    local transG = transparencyColor[2] / 255
    local transB = transparencyColor[3] / 255
    
    -- Tolerance for color matching (to account for compression artifacts)
    local tolerance = 0.01
    
    -- Iterate through all pixels and make matching ones transparent
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            local r, g, b, a = imageData:getPixel(x, y)
            
            -- Check if pixel matches transparency color (within tolerance)
            if math.abs(r - transR) < tolerance and
               math.abs(g - transG) < tolerance and
               math.abs(b - transB) < tolerance then
                -- Set pixel to transparent
                imageData:setPixel(x, y, r, g, b, 0)
            end
        end
    end
    
    -- Create Image from modified ImageData
    return love.graphics.newImage(imageData)
end

-- Load a sprite sheet with uniform sprite sizes
-- @param imagePath: path to the sprite sheet image
-- @param spriteWidth: width of each sprite in pixels
-- @param spriteHeight: height of each sprite in pixels
-- @param spacing: optional spacing between sprites (default: 0)
-- @param margin: optional margin around the sheet (default: 0)
-- @param transparencyColor: optional transparency color {R, G, B} (0-255)
-- @return: table with image and quads
function Spritesheet.load(imagePath, spriteWidth, spriteHeight, spacing, margin, transparencyColor)
    spacing = spacing or 0
    margin = margin or 0
    
    local image = applyTransparency(imagePath, transparencyColor)
    local imageWidth = image:getWidth()
    local imageHeight = image:getHeight()
    
    -- Calculate how many sprites fit horizontally and vertically
    local spritesPerRow = math.floor((imageWidth - margin * 2 + spacing) / (spriteWidth + spacing))
    local spritesPerCol = math.floor((imageHeight - margin * 2 + spacing) / (spriteHeight + spacing))
    
    local quads = {}
    
    -- Create quads for all sprites in the sheet
    for y = 0, spritesPerCol - 1 do
        for x = 0, spritesPerRow - 1 do
            local quad = love.graphics.newQuad(
                margin + x * (spriteWidth + spacing),
                margin + y * (spriteHeight + spacing),
                spriteWidth,
                spriteHeight,
                imageWidth,
                imageHeight
            )
            table.insert(quads, quad)
        end
    end
    
    return {
        image = image,
        quads = quads,
        spriteWidth = spriteWidth,
        spriteHeight = spriteHeight,
        spritesPerRow = spritesPerRow,
        spritesPerCol = spritesPerCol,
        totalSprites = #quads,
        -- Get a specific quad by index (1-based)
        getQuad = function(self, index)
            return self.quads[index]
        end,
        -- Get a quad by row and column (0-based)
        getQuadAt = function(self, col, row)
            return self.quads[row * self.spritesPerRow + col + 1]
        end,
        -- Draw a specific sprite
        draw = function(self, index, x, y, r, sx, sy)
            r = r or 0
            sx = sx or 1
            sy = sy or 1
            love.graphics.draw(self.image, self.quads[index], x, y, r, sx, sy)
        end
    }
end

-- Load a sprite sheet with custom sprite widths (non-uniform)
-- @param imagePath: path to the sprite sheet image
-- @param spriteWidths: table of sprite widths in pixels (e.g., {42, 47, 47, 47, 47})
-- @param spriteHeight: height of all sprites in pixels
-- @param margin: optional margin around the sheet (default: 0)
-- @param transparencyColor: optional transparency color {R, G, B} (0-255)
-- @return: table with image and quads
function Spritesheet.loadCustom(imagePath, spriteWidths, spriteHeight, margin, transparencyColor)
    margin = margin or 0
    
    local image = applyTransparency(imagePath, transparencyColor)
    local imageWidth = image:getWidth()
    local imageHeight = image:getHeight()
    
    local quads = {}
    local x = margin
    
    -- Create quads for each sprite with its custom width
    for i, width in ipairs(spriteWidths) do
        local quad = love.graphics.newQuad(
            x,
            margin,
            width,
            spriteHeight,
            imageWidth,
            imageHeight
        )
        table.insert(quads, quad)
        x = x + width
    end
    
    return {
        image = image,
        quads = quads,
        spriteWidths = spriteWidths,
        spriteHeight = spriteHeight,
        totalSprites = #quads,
        -- Get a specific quad by index (1-based)
        getQuad = function(self, index)
            return self.quads[index]
        end,
        -- Draw a specific sprite
        draw = function(self, index, x, y, r, sx, sy)
            r = r or 0
            sx = sx or 1
            sy = sy or 1
            love.graphics.draw(self.image, self.quads[index], x, y, r, sx, sy)
        end
    }
end

return Spritesheet
