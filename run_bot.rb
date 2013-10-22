#!/usr/bin/env ruby

require_relative 'loader.rb'
b =FoFBot::Bot.new('127.0.0.1', ARGV[0] || "test")
b.run(true)

require 'pry'
binding.pry
b.plant(["corn"])
b.continue
b.plant(["grass","grass"])
b.continue
b.plant(["corn"])
b.continue
b.plant(["grass","grass"])
b.continue
puts FoFBot.state.state["global"]
