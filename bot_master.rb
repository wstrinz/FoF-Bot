module FoFBot
  class BotMaster
    attr :host

    def initialize(host="127.0.0.1")
      @host = host
    end

    def start(room="test", args="", executable="run_bot")
      args = args.split(" ")
      wd = File.absolute_path(File.dirname(__FILE__))
      if args.size > 0
        pid = ChildProcess.build("#{wd}/#{executable}", room, *args)
      else
        pid = ChildProcess.build("#{wd}/#{executable}", room)
      end
      pid.start
      bots << pid
    end

    def bots
      @bots ||= []
    end
  end
end