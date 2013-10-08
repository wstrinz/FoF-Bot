fs = Dir.new('.').each.to_a.reject{|x| x[0] == '.' || x[-2..-1] != "rb" || x[0..3] == "load" || x[0..3] == "comb"}
str = fs.map{|f| open(f).read}.join("\n\n")
open('combined.rb','w'){|f| f.write str}