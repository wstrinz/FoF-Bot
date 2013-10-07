module FoFBot
  require 'redis'

  module EventManager

    def send_message(json, redis)
			redis.lpush("toJava#{FoFBot::config.redis_channel}", json)
		end

    def connect()
      @redis.subscribe(:"toRuby#{FoFBot::config.redis_channel}") do |on|
        on.message do |channel, msg|
          data = JSON.parse(msg)
          if(data["clientID"].to_s==FoFBot::config.client_id || data["clientID"] == FoFBot::config.room_name)
            yield data
          end
        end
      end
    end

  end

  class Connection
  	include FoFBot::EventManager

    def initialize
      @redis = Redis.new
    end

  end

end
require 'java'
java_package 'fof.bot'

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
require 'java'
java_package 'fof.bot'

module FoFBot

	extend self

	class << self
		def state
			@state ||= State.new	
		end
	end

  class State
    java_require ''

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

require 'java'

module FoFBot
  extend self

  class << self
    DEFAULTS = {room_name: 'test', name: 'bot1', redis_channel: 'dev', client_id: '8000'}
    def config(opts=DEFAULTS)
      @config ||= Config.new(DEFAULTS.merge(opts))
    end
  end

  java_package 'fof.bot'
  class Config
    java_package 'fof.bot'
    attr :options
    def initialize(opts)
      @options = opts
    end

    def room_name
      @options[:room_name]
    end

    def name
      @options[:name]
    end

    def redis_channel
    	@options[:redis_channel]
    end

    def client_id
    	@options[:client_id]
    end

    def client_id=(client_id)
    	@options[:client_id]=client_id
    end
  end
end
require 'java'
java_package 'fof.bot'

module FoFBot
	require 'json'
	module Messages

		def clid
			FoFBot::config.client_id
		end

		def roomID
			FoFBot::config.room_name
		end

		def farmerName
			FoFBot::config.name
		end

		def base
			{
				clientID: clid(),
				deviseName: "#{farmerName()}@#{farmerName()}.com",
				roomID: roomID()
			}
		end

		def joinRoom(roomName, farmerName, password="")
			# "event":"joinRoom","roomName":"test","password":"","userName":"a","clientID":"4","roomID":"test","deviseName":"wstrinz@gmail.com"
			msg = {
				event: "joinRoom",
				roomName: roomName,
				password: password,
				userName: farmerName,
				clientID: clid(),
				roomID: roomName,
        deviseName: "#{farmerName}@#{farmerName}.com"
      }
      msg.to_json
    end

    def getState(roomName, farmerName)
      # "event":"loadFromServer", "roomName":"test", "clientID":"18", "roomID":"test", "deviseName":"guest@guest.com"
      # "event":"getFarmerHistory", "clientID":"18", "roomID":"test", "deviseName":"guest@guest.com"
      # "event":"getFarmHistory", "clientID":"18", "roomID":"test", "deviseName":"guest@guest.com"

      msg = {
        event: 'loadFromServer',
        roomName: roomName,
        clientID: clid(),
        roomID: roomName,
        deviseName: "#{farmerName}@#{farmerName}.com"
      }
      
      msg.to_json
    end

		def plantField(field, crop)
			# "event":"plantField","field":1,"crop":"corn","clientID":"14","roomID":"test","deviseName":"wstrinz@gmail.com"
			msg = base.merge ({
				event: "plantField",
				field: field,
				crop: crop,
			})
			msg.to_json
		end

		def ready()
			# "event":"farmerReady","clientID":"14","roomID":"test","deviseName":"wstrinz@gmail.com"
			msg = base.merge ({
				event: "farmerReady",
			})
			msg.to_json
		end
	end

	class Message
		include Messages
	end
end
require 'java'
java_package 'fof.bot'

module FoFBot
  class Bot
    include FoFBot

    def initialize(room_name="test", name=nil,clientID=nil)
        unless name
            name = "bot#{Time.now.nsec}"
        end
        unless clientID
            clientID = (-1 - name.gsub('bot','').to_i).to_s
        end
        FoFBot::config(room_name: room_name, name: name, client_id: clientID)
        @con = FoFBot::Connection.new
        @room = room_name
        @name = name
        # @fib = @con.fiber
        @events = FoFBot::event_map
        setup_behavior()
    end

    def run(verbose=false)
      @redis = Redis.new
      t = Thread.new do
        @con.connect() do |event|
          puts "got #{event}" if verbose
          @events.event(event["event"],event)
        end
      end

      sleep(1)
      msg = FoFBot::Message.new().joinRoom(@room, @name)
      @con.send_message(msg,@redis)
      t.join()
    end

    def setup_behavior
        state = FoFBot.state
        FoFBot.setup_events do |events|

            events.register("changeSettings", lambda{|data|
                #"event":"changeSettings","clientID":8000,"mgmtOptsOn":false,"contractsOn":false,"fields":2
                # settings = (state["settings"] ||= {})
                # settings["mgmtOptsOn"] = data["mgmtOptsOn"]
                # settings["contractsOn"] = data["contractsOn"]
                # settings["fields"] = data["fields"]
                state.autoload(data,%w(mgmtOptsOn contractsOn fields),"settings")
            })

            events.register("advanceStage", lambda{|data|
                puts "advance Stage! yay "
                state.autoload(data,%w(year stageName stageNumber))
                open('state.json','w'){|f| f.write state.to_json}
                case data["stageName"]
                when "Plant"
                    plant()
                else
                    ready()
                end
                # state["year"] = data["year"]
                # state["stageName"] = data["stageName"]
                # state["stageNumber"] = data["stageNumber"]
            })

            events.register("joinRoom", lambda{|data|
                state["in_room"] = data["result"]
                if state["in_room"]
                  msg = FoFBot::Message.new().getState(@room, @name)
                  @con.send_message(msg,Redis.new)
                end
            })

            events.register("togglePause", lambda{|data|
                state["paused"] = data["state"]
                unless state["paused"]
                  msg = FoFBot::Message.new().getState(@room, @name)
                  @con.send_message(msg,Redis.new)
                end  
            })

            events.register("getWrapupInfo", lambda{|data|
                state.autoload(data["current"], data["current"].keys, "score")
            })

            events.register("getFarmInfo", lambda{|data|
                state["capital"] = data["capital"]
            })

            events.register("getLatestFieldHistory", lambda{|data|
                state["fields"] ||= {}
                data["fields"].each_with_index{|f,i|
                    ((state["fields"][i] ||= {})["history"] ||= {})[f["year"]] ||= {}
                    f.map{|k,v| state["fields"][i]["history"][f["year"]][k] = v}
                }
            })

            events.register("loadFromServer", lambda{|data|
                state["fields"] ||= {}
                data["fields"].each_with_index{|f,i|
                    (state["fields"][i] ||= {})["crop"] = f["crop"]

                }
            })

            events.register("getGameInfo", lambda{|data|
                state.autoload(data,%w(year enabledStages))
                state["stageNumber"] = data["stage"]
            })

            events.register("globalInfo", lambda{|data|
                state.autoload(data,%w(grassPrice, cornPrice))
            })
        end
    end

    def plant
        FoFBot.state["settings"]["fields"].times{|f|
            field = (FoFBot.state["fields"] ||= {})[f]
            # if field
            #   ## do thinking
            # else
            #   ## no history
            # array = gams_interface.call('model_name',state)
            array = ["corn","grass"]
            @con.send_message(Message.new().plantField(f,"corn"), Redis.new)
            # end
        }
        ready()
    end

    def join

        msg = FoFBot::Message.new().joinRoom(@room, @name)
        @con.send_message(msg,Redis.new)

    end

    def ready
        @con.send_message(Message.new().ready(), Redis.new)
    end

    def resume
        @con.connect
    end

    def connect_or_create

    end

    def config
      FoFBot::config
    end
  end
end