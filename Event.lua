class = class or require("Class")

local type_to_string = {"next","initial","final","error"}

local string_to_type = _.invert(type_to_string)

function is_type (event_type, this)
	if (type(event_type) == string) then
		local event_type = type_to_string[event_type]
	end
	return this.type == event_type
end

Event = class({
	initialize = function(this)
		-- Default to "next" type.
		this.type = string_to_type.next
		this._message = nil
	end,
	is_type = is_type,
	is_next = _.bind(is_type, string_to_type.next),
	is_initial = _.bind(is_type, string_to_type.initial),
	is_final = _.bind(is_type, string_to_type.final),
	is_error = _.bind(is_type, string_to_type.error),
	event_type = function(this, event_type)
		if (_.isNil(event_type)) then
			return type_to_string[this.type]
		elseif (type(event_type) == "string" and _.include(type_to_string, event_type)) then
			this.type = string_to_type[event_type]
		elseif (_.include(string_to_type, event_type)) then
			this.type = event_type
		end
		return this
	end,
	message = function(this, msg)
		if (_.isNil(msg)) then
			return this._message
		else
			this._message = msg
		end
		return this
	end,
	has_message = function(this)
		return (this:is_next() or this:is_initial())
	end,
	type_to_string = type_to_string,
	string_to_type = string_to_type
})

return Event
