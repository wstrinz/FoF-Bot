
module FoFBot
  require 'redis'
  require 'thread'

  module EventManager
    attr_accessor :queue
    attr :redis_host

    def send_message(json, redis)
			redis.lpush("toJava#{FoFBot::config.redis_channel}", json)
		end

    def connect()
      @redis.subscribe(:"toRuby#{FoFBot::config.redis_channel}") do |on|
        on.message do |channel, msg|
          data = JSON.parse(msg)
          if(data["clientID"].to_s==FoFBot::config.client_id || data["clientID"] == FoFBot::config.room_name)
            # puts "con got #{data}"
            @queue << data
          end
        end
      end
    end

  end

  class Connection
  	include FoFBot::EventManager

    def initialize(redis_host = '127.0.0.1')
      @redis_host = redis_host
      @redis = Redis.new(host: @redis_host)
      @queue = Queue.new
    end
  end

end