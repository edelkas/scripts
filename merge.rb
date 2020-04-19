def parse(n)
  print("    Enter map #{n} filename >> ")
  file = STDIN.gets.chomp
  while !File.file?(file)
    print("    File not found.\n    Enter map #{n} filename >> ")
    file = STDIN.gets.chomp
  end
  File.binread(file)
end

maps = []
print("How many maps do you want to merge? >> ")
n = STDIN.gets.chomp.to_i
(1..n).each{ |i| maps << parse(i) }
print("Which map to take overlapping tiles from? (1-#{n}) >> ")
k = STDIN.gets.chomp.to_i - 1

def comp(a,b)
  !(a==6 && b==7 || a==7 && b==6 || a==8 && b==9 || a==9 && b==8)
end

object_data = []
maps.each{ |map|
  object_data << map[1230..-1].split(//m).each_slice(5).to_a.map{ |s|
    s.map(&:ord)
  }
}
object_data = object_data.flatten(1).sort{ |a, b|
  comp(a[0], b[0]) ? a[0] <=> b[0] : 0
}.map{ |arr| arr.map(&:chr).join }.join

tile_data = []
(184..1149).each{ |b|
  tiles = maps.map{ |map| map[b].ord }
  if tiles.count(0) == n
    tile_data << 0
  elsif tiles.count(0) == n - 1
    tile_data << tiles.reject{ |t| t == 0 }[0]
  else
    tile_data << tiles[k]
  end
}
tile_data = tile_data.map(&:chr).join

object_counts = []
(0..39).each{ |obj|
  count = maps.map{ |map|
    map[1150 + 2 * obj..1150 + 2 * obj + 1].reverse.unpack('H*')[0].to_i(16)
  }.sum
  object_counts << [count.to_s(16).rjust(4, "0")].pack('H*').reverse
}
object_counts = object_counts.join

map = maps[0][0..183] + tile_data + object_counts + object_data
map[4..7] = [map.size.to_s(16).rjust(8, "0")].pack('H*').reverse
File.binwrite("merge_result", map)
print("Maps successfully merged into \'merge_result\'.")
