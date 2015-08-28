class = class or require("Class")
Observable = Observable or require("Observable")

EventStream = Observable:extend({
	initialize = function(this)
		this.subs = {}
		this.events = {}
	end,
	sink = function(this,event)
		_.push(this.events, event)
		this:observe()
		return this
	end,
	subscribe = function(this,sub)
		_.push(this.subs, sub)
		this:observe()
		return _.bindn(_.pull, this.subs, sub)
	end,
	observe = function(this)
		local routine = nil
		_.eachi(this.events, function(evn_key,evn)
			local routines = _.map(this.subs, function(sub_key, sub)
				return coroutine.create(_.bind(sub,evn))
			end)
			if (evn:is_error()) then
				_.push(actions, function(event)
					this:catch(event)
				end)
			end
			while (_.size(routines) > 0) do
				routine = _.pop(routines)
				coroutine.resume(routine)
				if (coroutine.status(routine) ~="dead") then
					_.push(routines,routine)
				end
			end
			-- Do cleanup at the end of the event, after all subscribers are satisfied.
			if (_.size(this.subs) > 0) then
				this.events[evn_key] = nil
			end
			if (evn:is_final()) then
				this.subs = {}
			end
		end)
	end,
	to_history = function(this, initial)
		return History:new(initial, this)
	end
})

return EventStream
