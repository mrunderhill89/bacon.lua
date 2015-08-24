class = class or require("Class")
Observable = Observable or require("Observable")
Property = class(_.extend(Observable, {
	initialize = function(this, initial)
		this.subs = {}
		this.events = {}
		this.initial = initial
		this.latest = nil
	end,
	subscribe = function(this,sub)
		_.push(this.subs, sub)
		if (_.size(this.events) <= 0) then
			if (not _.isNil(this.latest)) then
				sub(this.latest)
			elseif (not _.isNil(this.initial)) then
				sub(this.initial)
			end
		end
		this:observe()
		return _.bindn(_.pull, this.subs, sub)
	end,
	observe = function(this)
		local have_subs = _.size(this.subs)>0
		local routines = {}
		this.latest = this.latest or this.initial
		routines = _.flatten(
			_.map(this.events, function(evn_key,evn)
				if (have_subs) then
					--The event is already saved in "evn" 
					-- so we can remove it here, safely.
					this.events[evn_key] = nil
					this.latest = evn
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

return Property
