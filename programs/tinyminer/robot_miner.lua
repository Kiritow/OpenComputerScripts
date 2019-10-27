local robot = require('robot')
local component = require('component')
local computer = require('computer')

local function tickWork(state)
    if state.mode == 0 then
        print("switch back to normal.")
        component.inventory_controller.equip()
        state.mode = -1
    elseif state.mode > 0 then
        state.mode = state.mode - 1
    end
    local ok,err=robot.swing()
    if not ok then
        if err == "air" then
            print("got air, continue.")
        elseif err == "block" then
            print("got block, try to switch...")
            robot.select(4)
            component.inventory_controller.equip()
            state.mode = 1
        end
    else
        print("swing success.")
    end
    ok, err = robot.forward()
    if not ok then
        if err == 'impossible move' then
            print(string.format('cannot move forward. max distance: %d', state.distance))
            return false
        else
            print(string.format("got %s, continue", err))
        end
    else
        print("forward success.")
        state.distance = state.distance + 1
    end

    return true
end

local function tickHome(state)
    if state.distance <= 0 then
        print("reach destination")
        return false
    end
    local ok, err = robot.forward()
    if not ok then
        print(string.format("got %s, try to swing", err))
        robot.swing()
    else
        print("forward success")
        state.distance = state.distance - 1
    end

    return true
end

local current = {
    distance = 0,
    mode = -1
}

local startEngery = computer.energy()
local lowerEnergy = startEngery / 2 + 100
while tickWork(current) do
    local currentEnergy = computer.energy()
    print(string.format("current energy: %f", currentEnergy))
    if currentEnergy <= lowerEnergy then
        print("low energy detected.")
        break
    end
end
current.mode = -1
robot.turnAround()
while tickHome(current) do end
robot.turnAround()
