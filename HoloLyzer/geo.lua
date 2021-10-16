local cp = require("component")
h = cp.hologram
geo = cp.geolyzer
h.clear()

i3 = 0
i2 = 0

h.setScale(0.33)
h.setTranslation(0.020,0,0)

for i3=1, 32 do
    for i2=1, 32 do
        scan1 = ""
        scan1 = geo.scan(-16+i2,-16+i3,-16,1,1,48,true)
        tv1 = 0
        tv2 = 0
        for i1 = 1, #scan1 do
            if scan1[i1] ~= 0 then
                c1 = 3
            else
                c1 = 0
            end
            h.set(8+(32-i3),i1,8+(i2),c1)
            h.set(8+16,17,8+16,1)

            h.set(8,1,9,2)
            h.set(8+31,32,8+32,2)
            if scan1[i1] > 0 then
                s1 = i1
            end
            i1 = 1
        end
        print(i2.." "..i3)
    end
end

for i4=1, 30 do
    h.setScale(i4/60)
    print(math.min(i4/60, 0.33))
    h.setTranslation(0.020,i4/30,0)
    os.sleep(0.1)
end 