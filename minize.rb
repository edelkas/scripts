print "Enter filename: "
filename = STDIN.gets.chomp
map = File.binread(filename)
map[1230..-1] = map[1230..-1].split(//m).each_slice(5).to_a.map{ |s| s[0] == "\x19" ? s[1..-1].prepend("\x1B") : s }.join.force_encoding("ascii-8bit")
map[1204] = map[1200]
map[1205] = map[1201]
map[1200] = "\x00"
map[1201] = "\x00"
File.binwrite(filename + "_new", map.force_encoding("ascii-8bit"))
print("\nSuccess.\n")
