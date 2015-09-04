class = class or require("Class")
Observable = Observable or require("Observable")
EventStream = EventStream or require("EventStream")
History = History or require("History")

local numbers = EventStream.new()
local sum = numbers:scan(0, function(s,n) return s+n end):log("Sum")
_.eachi(_.range(10), function(value)
	numbers:push(value)
end)
numbers:close()

local channelA = History.new("Hello Channel A!")
local channelB = History.new("Hello Channel B!")
local channelC = History.new("Hello Channel C!")

local channel_switch = EventStream.new()
local channel_all = channel_switch:flatten():log("Channel All:")
local channel_latest = channel_switch:flatten_latest():log("Channel Latest:")
local channel_first = channel_switch:flatten_first():log("Channel First:")
channel_switch:push(channelA)
channel_switch:push(channelB)
channel_switch:push(channelC)
channelA:close()
channelB:close()
channelC:close()
channel_switch:close()
