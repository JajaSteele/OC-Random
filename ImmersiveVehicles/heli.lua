local component = require("component")
local term = require("term")
local v = component.vehicle
local g = component.gpu

local function pid(p,i,d)
    return{p=p,i=i,d=d,E=0,D=0,I=0,
		run=function(s,sp,pv)
			local E,D,A
			E = sp-pv
			D = E-s.E
			A = math.abs(D-s.D)
			s.E = E
			s.D = D
			s.I = A<E and s.I +E*s.i or s.I*0.5
			return E*s.p +(A<E and s.I or 0) +D*s.d
		end
	}
end

local function clamp(x,min,max) if x > max then return max elseif x < min then return min else return x end end

local function normalize_angle(angle)
    angle = angle % 360
    if angle > 180 then
        angle = angle - 360
    end
    return angle
end

if not v.isAvailable() then
    error("No vehicle")
end

local engine = v.getEngines()[0]
if not engine.state.running then
    if v.getFuel() == "" then
        error("NO FUEL!")
    end
    v.setMagnetoActive(0, true)
    v.setStarterActive(0, true)
    repeat
        engine = v.getEngines()[0]
        os.sleep(0.25)
    until engine.rpm >= engine.definition.engine.startRPM and engine.state.running
    v.setStarterActive(0, false)
end

g.setResolution(10,2)

local alt_pid = pid(10, 0, 5)

local throttle_value = 0
local target = 75

v.setRudderAngle(10)

local stat, err = pcall(function()
    while true do
        g.fill(1,1,10,2, " ")
        local x,y,z, dim = v.getLocation()
        term.setCursor(1,1)
        term.write(string.format("%.1f", y))
        term.setCursor(1,2)
        term.write(string.format("%.1f", throttle_value))
        throttle_value = clamp(alt_pid:run(target, y)/75, 0, 1)
        v.setThrottle(throttle_value)
        os.sleep(0)
    end
end)

local stat, err = pcall(function()
    v.setThrottle(0)
    v.setMagnetoActive(0, false)
    v.setRudderAngle(0)
end)
g.setResolution(g.maxResolution())