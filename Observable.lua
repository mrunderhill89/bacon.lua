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

_.pairs = function(obj)
	return _.map(obj, function(key,value)
		return {
			key=key,
			value=value
		}
	end)
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
	push = function(this,value, event_type)
		--[[
			Wraps a value around an event before calling sink() on it.
		]]--
		event_type  = event_type  or "next"
		return this:sink(Event.new():event_type(event_type):message(value))
	end,
	plug_from = function(this, from, ignore_final, ignore_errors)
		--[[
			Connects this streams' input to another's output.
			By default, final and error events are also passed in, but
			you can ignore them at your discretion.
			
			Returns a function that can be called to disconnect the two
			streams.
		]]--
		if (not ignore_final) then
			this:close_from(from)
		end
		if (not ignore_errors) then
			from:on_error(function(event)
				this:sink(event)
			end)
		end
		return from:on_value(function(value)
			this:push(value)
		end)
	end,
	plug_to = function(this, to, ignore_final, ignore_errors)
		--[[
			Inverse of plug_from(). Connects the "to" stream's input
			to this stream's output.
		]]--
		return to:plug_from(this, ignore_final, ignore_errors)
	end,
	close_from = function(this,from)
		--[[
			Causes this stream to close when the "from" stream closes.
			Useful for derived values which are no longer relevant once
			their base values have dried up.
		]]--
		from:on_final(_.bind(this.close, this))
		return this
	end,
	close_to = function(this,to)
		--[[
			Inverse of close_from(). When this stream closes, the "to"
			stream will, also.
		]]--
		to:close_from(this)
		return this
	end,
	map = function(this, map_func)
		--[[
			Converts a value received from the parent stream into a new
			value, using the given function. Works almost identically to
			map() from functional programming.
		]]--
		local child = EventStream.new():close_from(this)
		this:on_value(function(value)
			child:push(map_func(value))
		end)
		return child
	end,
	scan = function(this, seed, accumulate)
		--[[
			Creates a property that is updated whenever an event passes
			through the parent stream. Similar to reduce() in functional
			programming, but also passes intermediary values along.
		]]--
		local store = History.new(seed):close_from(this)
		this:sample_from(store, function(values)
			return accumulate(values[2],values[1])
		end):plug_to(store)
		return store
	end,
	combine = function(streams, hot, combine)
		--[[
			Core function for combining streams. Note that this
			takes a TABLE of streams as its first argument, so you CANNOT use it
			with "some_observable:combine()". Use "Observable.combine({some_observable,...})"
			instead or use "combine_with."
			streams - table containing all streams you want to combine.
				keys are used to store resulting values.
			hot - table of all streams that will trigger a new result
				regardless of whether they've been listened to already.
			combine - function that produces a result from a table of
				values coming from each provided stream.
		]]--
		local result = EventStream.new()
		local data = _.reduce(
			_.pairs(streams),
			function(data, kv)
				local index = kv.key
				local obs = kv.value
				local is_hot = _.contains(hot,obs)
				data.values[index] = nil
				data.waiting[index] = true
				data.remaining = data.remaining + 1
				result:close_from(obs)
				local unsub = obs:on_value(function(value)
					data.values[index] = value
					if (data.waiting[index]) then
						data.remaining = data.remaining - 1
					end
					if (data.remaining == 0 and (is_hot or data.waiting[index])) then
						data.waiting[index] = false
						result:push(combine(data.values))
					end
					data.waiting[index] = false
				end)
				result:on_final(unsub)
				return data
			end,
			{
				values = {},
				waiting = {},
				remaining = 0
			}
		)
		return result
	end, 
	combine_with = function(this, that, combine)
		--[[
			Simplified and inline version of "combine," similar to 
			Bacon.js's version. New values are computed when EITHER stream
			receives a new value.
		]]--
		return Observable.combine({this, that},{this,that},combine)
	end,
	sample_from = function(this, that, combine)
		--[[
			New values are computed when THIS stream receives a new value,
			but not THAT stream.
		]]--
		return Observable.combine({this,that},{this},combine)
	end,
	sample_to = function(this,that,combine)
		--[[
			New values are computed when THAT stream receives a new value,
			but not THIS stream. Similar to "SampledBy" in Bacon.js.
		]]--
		return Observable.combine({this,that},{that},combine)
	end,
	group = function(this)
		--[[
			Common scan function that simply pushes new values into an
			array.
		]]--
		return this:scan({}, function(group, value)
			_.push(group, value)
			return group
		end)
	end,
	group_kv = function(this)
		--[[
			Common scan function that sets the values of a table using
			a key/value pair. Pushes the table after every change.
		]]--
		return this:scan({}, function(group, kv)
			group[kv.key] = kv.value
			return group
		end)
	end,
	branch = function(this, select_branch, num_branches, prepare_branches)
		--[[
			Directs values to multiple different event streams depending
			on an integer function. Use the "prepare_branches" function 
			to perform operations on each branch after they've been set 
			up.
			select_branch: 
				value(anything) -> number(preferably an integer)
			prepare_branch: 
				this(observable), branches(eventstream[]) -> eventstream
		]]--
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
		--[[
			Directs values to two different event streams depending
			on a boolean function. By default, the pass stream is 
			returned just like in Bacon.js, but this can be changed. 
			The "prepare_pass_fail" function initializes the pass and 
			fail streams and determines which stream is used to continue 
			the chain.
			test:
				value(anything) -> bool
			prepare_pass_fail:
				this, pass, fail -> observable
		]]--
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
	skip_duplicates = function(this)
		--[[
			Skips events with repeating messages.
		]]--
		return this:scan(nil, function(last,value)
			local changed = (last ~= value)
			return {changed = changed, value = value}
		end):filter(function(tuple) return tuple.changed end)
		:map(function(tuple) return tuple.value end)
	end,
	flatten = function(this)
		--[[
			Converts a stream of observables into a single observable
			containing the results from each one received. Think of it
			like how flatten works in Underscore or Moses: instead of
			having an array of arrays, you have a single array with all
			of the values. Note that flatten() listens to EVERY stream
			provided by the base stream, so make sure to close streams
			with obsolete data.
		]]--
		local output = EventStream.new():close_from(this)
		local branch = this:scan({}, function(branches, stream)
			if (stream) then
				if (not branches[stream]) then
					branches[stream] = stream:plug_to(output, true)
					stream:on_final(function()
						branches[stream] = nil
					end)
				end
			end
			return branches
		end)
		return output
	end,
	flatten_latest = function(this)
		--[[
			Converts a stream of observables into a single observable
			containing the results from -only- the latest one received.
			This is similar to changing the channel on your TV. Note 
			that any events from streams not being listented to are 
			IGNORED, so make sure you really only need the latest 
			information; otherwise, use flatten() and filter the data 
			yourself.
		]]--
		local output = EventStream.new():close_from(this)
		local unplug = nil
		local latest = this:scan(nil, function(latest, stream)
			if (latest) then
				--unsubscribe previous
				unplug()
			end
			if (stream) then
				--subscribe next
				unplug = stream:plug_to(output, true)
			end
			return stream
		end)
		return output
	end,
	flatten_first = function(this)
		--[[
			Converts a stream of observables into a single observable,
			switching automatically from one observable to the next as
			each one closes. Note that any events from streams not being
			listented to are IGNORED.
		]]--
		local output = EventStream.new():close_from(this)
		local branch = this:scan({}, function(branches, stream)
			if (stream) then
				_.push(branches, stream)
				stream:on_final(function(event)
					branch:push(_.pull(branches, stream))
				end)
			end
			return branches
		end)
		local current = branch:map(function(branches)
			return _.first(branches,1)[1]
		end):skip_duplicates():on_value(function(stream) 
			stream:plug_to(output, true)
		end)
		return output
	end,
	flat_map = function(this, switch)
		return this:map(switch):flatten()
	end,
	flat_map_latest = function(this, switch)
		return this:map(switch):flatten_latest()
	end,
	flat_map_first = function(this, switch)
		return this:map(switch):flatten_first()
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
