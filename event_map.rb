module FoFBot
	extend self

	class << self
		def setup_events
			yield event_map
		end

		def event_map
			@event_map ||= EventMap.new
		end
	end

	class EventMap
		def register(event, operation)
			raw_map[event] ||= []
			raw_map[event] << operation
		end

		def register_single(event, operation)
			raw_map[:single][event] ||= []
			raw_map[:single][event] << operation
		end

		def raw_map
			@map ||= {single:{}}
		end

		def event(event_name,data)
			if raw_map[:single][event_name]
				raw_map[:single][event_name].each{|op| op.call(data)}
				raw_map[:single].delete(event_name)
			end
			if raw_map[event_name]
				raw_map[event_name].each{|op| op.call(data)}
			end
		end
	end
end