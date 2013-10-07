module FoFBot
	extend self

	class << self
		def state
			@state ||= State.new	
		end
	end

	class State

		def state
			@state ||= {}
		end

		def [](key)
			state[key]
		end

		def []=(key,value)
			state[key]=value
		end

		def to_s
			state.to_s
		end

		def autoload(data, values, key=nil)
			if key
				state[key] ||= {}
				(data.keys & values).map{|k|
					state[key][k]=data[k]
				}
			else
				(data.keys & values).map{|k|
					state[k]=data[k]
				}
			end
		end
	end
end