cp = require("component")
shell = require("shell")

g = cp.gpu

X1,Y1 = g.maxResolution()

g.setResolution(X1,Y1)

shell.execute("clear")