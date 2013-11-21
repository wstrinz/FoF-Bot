module FoFBot
  class Bot
    include FoFBot

    def initialize(redis_url = '127.0.0.1', room_name="test", name=nil,clientID=nil)
        time_seed = Time.now.nsec
        rand_seed = rand(10000)
        unless name
          name = "bot#{time_seed.to_s(32)}_#{rand_seed}"
        end
        unless clientID
          clientID = "#{time_seed.to_s(32)}_#{rand_seed}_#{name}"
        end
        FoFBot::config(room_name: room_name, name: name, client_id: clientID)
        @con = FoFBot::Connection.new redis_url
        @room = room_name
        @name = name
        @events = FoFBot::event_map
        setup_behavior()
    end

    def run(verbose=false)
      @redis = Redis.new(host: @con.redis_host)
      t_con = Thread.new do
        @con.connect()
      end

      sleep(1)
      msg = FoFBot::Message.new().joinRoom(@room, @name)
      @con.send_message(msg,@redis)
      event_loop(verbose)
    end

    def continue(verbose=false)
        ready()
        event_loop(verbose)
    end

    def event_loop(verbose=false)
        catch(:plant) do
            loop do
                event = @con.queue.pop
                puts "got #{event}" if verbose
                @events.event(event["event"],event)
            end

        end
        sleep (1)
        while @con.queue.size > 0 do
            event = @con.queue.pop
            puts "got #{event}" if verbose
            @events.event(event["event"],event)
        end
    end

    def setup_behavior
        state = FoFBot.state
        FoFBot.setup_events do |events|

            events.register("changeSettings", lambda{|data|
                state.autoload(data,%w(mgmtOptsOn contractsOn fields),"settings")
            })

            events.register("kickPlayer", lambda{|data|
                if data["result"] && data["player"] == @name
                    puts "kicked!"
                    exit()
                end
            })

            events.register("advanceStage", lambda{|data|
                puts "advance Stage! yay "
                state.autoload(data,%w(year stageName stageNumber))
                case data["stageName"]
                when "Plant"
                    plant_stage()
                else
                    ready()
                end
            })

            events.register("joinRoom", lambda{|data|
                state["in_room"] = data["result"]
                if state["in_room"]
                  msg = FoFBot::Message.new().getState(@room, @name)
                  @con.send_message(msg,Redis.new(host: @con.redis_host))
                end
            })

            events.register("togglePause", lambda{|data|
                state["paused"] = data["state"]
                unless state["paused"]
                  msg = FoFBot::Message.new().getState(@room, @name)
                  @con.send_message(msg,Redis.new(host: @con.redis_host))
                end
            })

            events.register("getWrapupInfo", lambda{|data|
                state.autoload(data["current"], data["current"].keys, "score")
            })

            events.register("getFarmInfo", lambda{|data|
                state["capital"] = data["capital"]
            })

            events.register("fieldDump", lambda{|data|
                (state["global"] ||= []) << data["fields"]
                state["global"].flatten!
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
                    %w[SOM GBI tillage fertilizer crop x y].each{|prop|
                        (state["fields"][i] ||= {})[prop] = f[prop] if f[prop] != nil
                    }
                }
            })

            events.register("getGameInfo", lambda{|data|
                state.autoload(data,%w(year enabledStages))
                state["stageNumber"] = data["stage"]
            })

            events.register("globalInfo", lambda{|data|
                state.autoload(data,%w(cornPrice))
                state.autoload(data,%w(grassPrice)) if data["grassPrice"]
            })
        end
    end

    def plant_stage
        throw(:plant)
    end

    def plant(crops)
        crops.each_with_index do |crop,i|
            @con.send_message(Message.new().plantField(i,crop), Redis.new(host: @con.redis_host))
        end
    end

    def manage(field, technique, value)
        @con.send_message(Message.new().manageField(field, technique, value), Redis.new(host: @con.redis_host))
    end

    def join

        msg = FoFBot::Message.new().joinRoom(@room, @name)
        @con.send_message(msg,Redis.new(host: @con.redis_host))

    end

    def ready
        @con.send_message(Message.new().ready(), Redis.new(host: @con.redis_host))
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