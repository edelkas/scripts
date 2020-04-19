def check(i)
  if i < 0 || i > 28
    puts "ID out of range (0-28)."
    return -1
  end
  if [3,4,6,7,8,9].include?(i)
    puts "Sorry, doors are not yet supported."
    return -1
  end
  return 0
end
print "Enter filename: "
filename = gets.chomp
if !File.file?(filename)
  puts "File not found."
  return
end
print "Input ID: "
input = STDIN.gets.chomp.to_i
return if check(input) == -1
print "Output ID: "
output = STDIN.gets.chomp.to_i
return if check(output) == -1
map = File.binread(filename)
count = 0
objects = map[1230..-1].split(//).each_slice(5).to_a.map{ |s|
  if s[0] == [input.to_s(16).rjust(2,"0")].pack('H*')
    count += 1
    s[0] = [output.to_s(16).rjust(2,"0")].pack('H*')
    s[3] = [0.to_s(16).rjust(2,"0")].pack('H*')
    s[4] = [0.to_s(16).rjust(2,"0")].pack('H*')
    s
  else
    s
  end
}.sort_by{ |s|
  id = s[0].unpack('H*')[0].to_i(16)
  if ![6,7,8,9].include?(id) then id else 5 end
}.join.force_encoding("ascii-8bit")
map[1230..-1] = objects
map[1150+2*input..1150+2*input+1] = [0.to_s(16).rjust(4,"0")].pack('H*').reverse
current = map[1150+2*output..1150+2*output+1].reverse.unpack('H*')[0].to_i(16)
map[1150+2*output..1150+2*output+1] = [(current+count).to_s(16).rjust(4,"0")].pack('H*').reverse
File.binwrite(filename + "s", map.force_encoding("ascii-8bit"))
puts "Success, #{count} objects changed."
