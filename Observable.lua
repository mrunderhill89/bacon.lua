Observable = {
	subscribe = function(this,sub)
		_.push(this.subs, sub)
		this:observe()
		return _.bindn(_.pull, this.subs, sub)
	end,
	on_value = function(this, sub)
		return this:subscribe(sub)
	end,
	sink = function(this,event)
		_.push(this.events, event)
		this:observe()
		return this
	end,
	push = function(this,value)
		return this:sink(value)
	end,
	map = function(this, map_func)
		local child = EventStream.new()
		this:on_value(function(value)
			child:push(map_func(value))
		end)
		return child
	end,
	scan = function(this, seed, accumulate)
		local child = Property.new(seed)
		local store = seed
		this:on_value(function(value)
			store = accumulate(store, value)
			child:push(store)
		end)
		return child
	end
}

return Observable
