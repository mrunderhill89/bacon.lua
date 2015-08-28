Observable = Observable or require("Observable")
Event = Event or require("Event")
EventStream = EventStream or require("EventStream")

History = Observable:extend({
	initialize = function(this, initial, stream)
		this.stream = stream or EventStream.new()
		this.history = {}
		this.stream:subscribe(function(evn)
			_.push(this.history, evn)
		end)
		if (not _.isNil(initial)) then
			this.stream:sink(Event.new():event_type("initial"):message(initial))
		end
	end,
	subscribe = function(this,sub)
		if (_.size(this.history) > 0) then
			sub(_.last(this.history,1)[1])
		end
		return this.stream:subscribe(sub)
	end,
	close = function(this, event)
		this.stream:close()
	end,
	sink = function(this, event)
		this.stream:sink(event)
		return this
	end
})

return History
