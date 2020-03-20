def speedrunize(folder, filename)
  map = File.binread(folder + "/" + filename)
  objects = map[1230..-1].split(//).each_slice(5).to_a.reject{ |s| s[0] == "\x02" }.join.force_encoding("ascii-8bit")
  map[1230..-1] = objects
  map[4..7] = (1230 + objects.size).to_s(16).rjust(8, "0").scan(/../).reverse.map{ |b| [b].pack('H*')[0] }.join.force_encoding("ascii-8bit")
  map[1154] = "\x00"
  map[1155] = "\x00"
  File.binwrite(folder + "_s/" + filename + "_s", map.force_encoding("ascii-8bit"))
rescue
end
print "Enter folder name: "
folder = gets.chomp
Dir.mkdir(folder + "_s")
files = Dir.entries(folder).reject{ |f| !File.file?(folder + "/" + f) }.each{ |f| speedrunize(folder, f) }
puts "Success."
