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
        @events = FoFBot::event_map
        setup_behavior()
    end

    def run(verbose=false)
      @redis = Redis.new
      t_con = Thread.new do
        @con.connect()
      end

      sleep(1)
      msg = FoFBot::Message.new().joinRoom(@room, @name)
      @con.send_message(msg,@redis)
      continue()
    end

    def continue
        t = Thread.new do
            catch(:plant) do
              loop do
                event = @con.queue.pop
                puts "got #{event}" #if verbose
                @events.event(event["event"],event)
              end
            end

            sleep (1)
            while @con.queue.size > 0 do
              event = @con.queue.pop
              puts "got #{event}" #if verbose
              @events.event(event["event"],event)
            end
        end
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
                # open('state.json','w'){|f| f.write state.to_json}
                case data["stageName"]
                when "Plant"
                    plant_stage()
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

    def plant_stage
        # FoFBot.state["settings"]["fields"].times{|f|
        #     field = (FoFBot.state["fields"] ||= {})[f]
        #     # if field
        #     #   ## do thinking
        #     # else
        #     #   ## no history
        #     # array = gams_interface.call('model_name',state)
        #     array = ["corn","grass"]
        #     # @con.send_message(Message.new().plantField(f,"corn"), Redis.new)
        #     # end
        # }
        throw(:plant)
        # ready()
    end

    def plant(crops)
        crops.each_with_index do |crop,i|
            @con.send_message(Message.new().plantField(i,crop), Redis.new)
        end
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