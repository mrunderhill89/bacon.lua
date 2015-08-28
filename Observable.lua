class = class or require("Class")
Event = Event or require("Event")

function wrap_subscriber(sub)
	return function(event)
		if (event:has_message())then
			sub(event:message())
		end
	end
end

function virtual(name)
	return function()
		error(name.." should be defined in a subclass using extend(), not called directly.")
	end
end

Observable = class({
	subscribe = virtual("Observable.subscribe"),
	sink = virtual("Observable.sink"),
	close = function(this)
		this:sink(Event.new():event_type("final"))
	end,
	catch = function(event)
		error(event:message() or "Observable: unknown error event.")
	end,
	on_value = function(this, sub)
		return this:subscribe(wrap_subscriber(sub))
	end,
	on_final = function(this, sub)
		return this:subscribe(function(event)
			if (event:is_final()) then
				sub(event)
			end
		end)
	end,
	on_error = function(this, sub)
		return this:subscribe(function(event)
			if (event:is_error()) then
				sub(event)
			end
		end)
	end,
	push = function(this,value)
		return this:sink(Event.new():message(value))
	end,
	plug_from = function(this, from)
		return from:subscribe(function(event)
			this:sink(event)
		end)
	end,
	plug_to = function(this, to)
		return to:plug_from(this)
	end,
	close_from = function(this,from)
		from:on_final(_.bind(this.close, this))
		return this
	end,
	close_to = function(this,to)
		to:close_from(this)
		return this
	end,
	map = function(this, map_func)
		local child = EventStream.new():close_from(this)
		this:on_value(function(value)
			child:push(map_func(value))
		end)
		return child
	end,
	scan = function(this, seed, accumulate)
		local child = History.new(seed):close_from(this)
		local store = seed
		this:on_value(function(value)
			store = accumulate(store, value)
			child:push(store)
		end)
		return child
	end,
	branch = function(this, select_branch, num_branches, prepare_branches)
		local branches = _.map(_.range(num_branches), function(key,value)
			return EventStream.new():close_from(this)
		end)
		this:on_value(function(value)
			local selected = select_branch(value)
			if (branches[selected]) then
				branches[selected]:push(value)
			end
		end)
		return prepare_branches(this, branches)
	end,
	filter = function(this, test, prepare_pass_fail)
		if (not _.isFunction(prepare_pass_fail)) then
			prepare_pass_fail = function(this, pass, fail) 
				return pass
			end
		end
		return this:branch(
			function(value)
				if (test(value)) then return 1 else return 2 end
			end,
			2,
			function(this, branches)
				return prepare_pass_fail(this, branches[1], branches[2])
			end
		)
	end,
	flat_map = function(this, switch)
		local output = EventStream.new()
		
	end,
	yield = function(this)
		local child = EventStream.new():close_from (this)
		this:subscribe(function(event)
			if (coroutine.running()) then
				coroutine.yield()
			end
			child:sink(event)
		end)
		return child
	end,
	yield_after = function(this)
		local child = EventStream.new():close_from (this)
		this:subscribe(function(event)
			child:sink(event)
			if (coroutine.running()) then
				coroutine.yield()
			end
		end)
		return child
	end,
	log = function(this, label)
		this:on_value(function(data) 
			print(label..":"..data)
		end)
		this:on_final(function(data) 
			print(label..": closed")
		end)
		return this
	end
})

return Observable
