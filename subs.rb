print "Filename >> "
filename = STDIN.gets.chomp
print "Input ID >> "
input = STDIN.gets.chomp.to_i
print "Output ID >> "
output = STDIN.gets.chomp.to_i
map = File.binread(filename)
map[1230..-1] = map[1230..-1].split(//m).each_slice(5).to_a.map{ |s| s[0] == input.chr ? s[1..-1].prepend(output.chr) : s }.join.force_encoding("ascii-8bit")
map[1150+2*output] = (map[1150+2*input].ord + map[1150+2*output].ord).chr
map[1151+2*output] = (map[1151+2*input].ord + map[1151+2*output].ord).chr
map[1150+2*input] = "\x00"
map[1151+2*input] = "\x00"
File.binwrite(filename + "_new", map.force_encoding("ascii-8bit"))
print("Success.\n")
