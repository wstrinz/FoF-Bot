module FoFBot
  extend self

  class << self
  	DEFAULTS = {room_name: 'test', name: 'bot1', redis_channel: 'dev', client_id: '8000'}
    def config(opts=DEFAULTS)
      @config ||= Config.new(DEFAULTS.merge(opts))
    end
  end

  class Config
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