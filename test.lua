class = class or require("Class")
Observable = Observable or require("Observable")
EventStream = EventStream or require("EventStream")
Property = Property or require("Property")

local numbers = EventStream.new()
local sum = numbers:scan(0,function(s,n) return s+n end)
sum:on_value(function(s) print(s) end)
numbers:sink(1)
numbers:sink(2)
numbers:sink(3)
numbers:sink(4)
