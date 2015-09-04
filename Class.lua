_ = _ or require("moses")

function class(params)
	local proto = params or {}
	proto.__index = proto

	proto.extend = function(base, subparams)
		local subclass = class(subparams)
		setmetatable(subclass, base)
		return subclass
	end

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

function type_check(value,type_name, nil_okay)
	return type(value) == type_name or (value == nil and nil_okay)
end

function assert_type(value, type_name, nil_okay)
	assert(type_check(value,type_name,nil_okay), "Expected type "..type_name..". Got "..type(value).." "..tostring(value).." instead.")
end

return class
