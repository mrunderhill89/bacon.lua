_ = _ or require("moses")

function class(proto, static)
	local static = static or {}
	static.proto = proto or {}
	static.__index = static

	local proto = static.proto 
	proto.__index = proto
	setmetatable(proto,static)

	proto.constructor = function(instance, ...)
		local instance = instance or {}
		setmetatable(instance,proto)
		if (_.isFunction(proto.initialize)) then 
			proto.initialize(instance, ...)
		end
		return instance
	end
	
	proto.new = function(...)
		return proto.constructor({}, ...)
	end
	return proto
end

function table.tostring(t)
	local text = _.reduce(
		_.map(t, function(key,value)
			return tostring(key)..":"..tostring(value).."\n"
		end),
		function(rest,line)
			return rest..line
		end,
		""
	)
	return "{\n"..text.."}"
end

return class
