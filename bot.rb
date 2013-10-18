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
      event_loop()
    end

    def continue(verbose=false)
        ready()
        event_loop(verbose)
    end

    def event_loop(verbose=false)
        t = Thread.new do
            catch(:plant) do
              loop do
                event = @con.queue.pop
                puts "got #{event}" if verbose
                @events.event(event["event"],event)
              end

                sleep (1)
                while @con.queue.size > 0 do
                  event = @con.queue.pop
                  puts "got #{event}" if verbose
                  @events.event(event["event"],event)
                end
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
                #{"event"=>"fieldDump", "clientID"=>"test", "fields"=>[{"farm"=>"bot9fl1u_2436", "pesticide"=>false, "SOM"=>50.0, "yield"=>0.0, "GBI"=>0.016892175971779624, "year"=>2, "fertilizer"=>false, "till"=>false, "crop"=>"FALLOW", "y"=>2, "x"=>1}, {"farm"=>"bot9fl1u_2436", "pesticide"=>false, "SOM"=>100.0, "yield"=>0.0, "GBI"=>0.016892175971779624, "year"=>2, "fertilizer"=>false, "till"=>false, "crop"=>"FALLOW", "y"=>2, "x"=>2}, {"farm"=>"botlhottc_4226", "pesticide"=>false, "SOM"=>100.0, "yield"=>0.0, "GBI"=>0.016892175971779624, "year"=>0, "fertilizer"=>false, "till"=>false, "crop"=>"FALLOW", "y"=>2, "x"=>3}, {"farm"=>"botlhottc_4226", "pesticide"=>false, "SOM"=>50.0, "yield"=>0.0, "GBI"=>0.016892175971779624, "year"=>0, "fertilizer"=>false, "till"=>false, "crop"=>"FALLOW", "y"=>2, "x"=>4}, {"farm"=>"botcvah6f_1023", "pesticide"=>false, "SOM"=>90.52631578947368, "yield"=>13.401855469557047, "GBI"=>0.07112278851859129, "year"=>0, "fertilizer"=>false, "till"=>false, "crop"=>"CORN", "y"=>4, "x"=>1}, {"farm"=>"botcvah6f_1023", "pesticide"=>false, "SOM"=>50.0, "yield"=>0.0, "GBI"=>0.07112278851859129, "year"=>0, "fertilizer"=>false, "till"=>false, "crop"=>"FALLOW", "y"=>4, "x"=>2}]}
                state["global"] ||= {}
                puts data
                data["fields"].each do |f|
                    farm = f["farm"]
                    year = f["year"]
                    (state["global"][farm] ||= {})[year] ||= {}

                    # (f.keys - ["farm"]).each
                end
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
                        (state["fields"][i] ||= {})[prop] = f[prop]
                    }
                    # (state["fields"][i] ||= {})["crop"] = f["crop"]
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
        #     # @con.send_message(Message.new().plantField(f,"corn"), Redis.new(host: @con.redis_host))
        #     # end
        # }
        throw(:plant)
        # ready()
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