class = class or require("Class")
Observable = Observable or require("Observable")

EventStream = class(_.extend(Observable, {
	initialize = function(this)
		this.subs = {}
		this.events = {}
	end,
	observe = function(this)
		local have_subs = _.size(this.subs)>0
		local routines = _.flatten(
			_.map(this.events, function(evn_key,evn)
				if (have_subs) then
					--The event is already saved in "evn" 
					-- so we can remove it here, safely.
					this.events[evn_key] = nil
				end
				return _.map(this.subs, function(sub_key, sub)
					return coroutine.create(_.bind(sub,evn))
				end)
			end)
		)
		while (_.size(routines) > 0) do
			routine = _.pop(routines)
			coroutine.resume(routine)
			if (coroutine.status(routine) ~="dead") then
				_.push(routines,routine)
			end
		end
	end
}))

local test = EventStream.new()
local map_test = test:map(function(message)
	return "Hello "..message.."!"
end)

return EventStream
