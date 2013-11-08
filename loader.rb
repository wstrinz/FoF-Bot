require 'json'
require 'childprocess'
require 'redis'
files = %w(bot.rb bot_master.rb config.rb connection.rb messages.rb state.rb event_map.rb)
files.each { |f| load File.dirname(__FILE__) + "/" + f }