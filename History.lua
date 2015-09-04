Observable = Observable or require("Observable")
Event = Event or require("Event")
EventStream = EventStream or require("EventStream")

function wrap_subscriber_multi(sub)
	return function(events)
		local messages = _.map(
			_.filter(
				events,
				function(k,event)
					return event:has_message()
				end
			),
			function(k,event)
				return event:message()
			end
		)
		print(unpack(messages))
		sub(unpack(messages))
	end
end

_.last_or_all= function(array, n)
	if (n >= _.size(array)) then return array end
	return _.last(array,n)
end

History = Observable:extend({
	initialize = function(this, initial)
		this.subs = {}
		this.events = {}
		this._maintain = 1
		if (not _.isNil(initial)) then
			this:sink(Event.new():event_type("initial"):message(initial))
		end
	end,
	sink = function(this,event)
		_.push(this.events, event)
		this:observe()
		return this
	end,
	subscribe = function(this,sub)
		_.push(this.subs, sub)
		this:observe_single(sub)
		return _.bindn(_.pull, this.subs, sub)
	end,
	on_value = function(this,sub)
		return this:subscribe(wrap_subscriber_multi(sub))
	end,
	maintain = function(this, set)
		if (not _.isNumber(set)) then 
			return this._maintain
		end
		this._maintain = set
		return this
	end,
	subset_events = function(this)
		local result = _.reduce(_.reverse(this.events), function(base, event)
			if (event:is_final()) then
				return {
					using={},
					final=event,
					errors={}
				}
			elseif (event:is_error()) then
				_.push(base.errors, event)
			elseif (_.size(base.using) < this:maintain()) then
				_.push(base.using, event)
			end
			return base
		end,
			{
				using={},
				final=nil,
				errors={}
			}
		)
		result.using = _.reverse(result.using)
		return result
	end,
	observe = function(this)
		local sub_events = this:subset_events()
		if (_.size(sub_events.errors)>0) then
			_.each(sub_events.errors, this.catch)
		else
			if (_.size(sub_events.using) >= this:maintain() and _.size(this.subs) > 0) then
				local routines = _.map(this.subs, function(key, sub)
					return coroutine.create(_.bind(sub,sub_events.using))
				end)
				while (_.size(routines) > 0) do
					routine = _.pop(routines)
					coroutine.resume(routine)
					if (coroutine.status(routine) ~="dead") then
						_.push(routines,routine)
					end
				end
				this.events = sub_events.using
			end
			if (not _.isNil(sub_events.final)) then
				this.events = {}
				this.subs = {}
			end
		end
	end,
	observe_single = function(this,sub)
		local sub_events = this:subset_events()
		if (_.size(sub_events.using) == this.maintain) then
			local routine = coroutine.create(_.bind(sub,sub_events.using))
			while (coroutine.status(routine) ~= "dead") do
				coroutine.resume(routine)
			end
			this.events = sub_events.using
		end
		if (sub_events.final) then
			this.events = {}
			this.subs = {}
		end
	end
})

return History
