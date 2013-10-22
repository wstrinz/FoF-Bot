#!/usr/bin/env ruby

require_relative 'combined.rb'
# require_relative 'loader.rb'
b =FoFBot::Bot.new('127.0.0.1', ARGV[0] || "test", 
  ARGV[1] || "B_#{Time.now.nsec.to_s(32)}_#{rand(100)}")
b.run(true)

b.plant(["corn"])
b.continue
b.plant(["grass","grass"])
b.continue
b.plant(["corn"])
b.continue
b.plant(["grass","grass"])
b.continue
puts FoFBot.state.state["global"]
