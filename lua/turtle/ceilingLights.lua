local tArgs = { ... }
if #tArgs ~= 3 then
    print("Usage: ceilingLights <gap between lights> <number of rows (forward)> <number of columns (to side)>")
    print("")
    print("Place turtle under first ceiling light position.")
    print("Refuel turtle, and add sea lanterns to active slot.")
    print("Wall must be on the turtle's right side.")
    return
end

local LIGHTS_GAP = tonumber(tArgs[1])
local ROWS = tonumber(tArgs[2])
local COLUMNS = tonumber(tArgs[3])

local neededFuel = LIGHTS_GAP * ROWS * COLUMNS

if turtle.getFuelLevel() < neededFuel then
    print("Not enough fuel. Refuel the turtle.")
    return
end

for i = 1, COLUMNS, 1 do
    for j = 1, ROWS, 1 do
        turtle.digUp()
        turtle.placeUp()
        if j < ROWS then
            for g = 1, LIGHTS_GAP + 1, 1 do
                turtle.forward()
            end
        end
    end
    if i < COLUMNS then
        if i % 2 == 0 then
            turtle.turnRight()
        else
            turtle.turnLeft()
        end
        for g = 1, LIGHTS_GAP + 1, 1 do
            turtle.forward()
        end
        if i % 2 == 0 then
            turtle.turnRight()
        else
            turtle.turnLeft()
        end
    end
end