#!/usr/bin/env ruby

# User input
print("Enter filename: ")
filename = STDIN.gets.chomp
range_start = ARGV[0].to_i
range_end = ARGV[1].to_i

# Find and sort versions of file to track
files = Dir.entries(Dir.pwd).select{ |f|
  File.file?(f) && f.length >= filename.length && f[0..filename.length-1] == filename
}.reject{ |f|
  f.sub(/\.[^.\/]*\Z/, "").sub(/\d*\Z/, "") != filename
}.map{ |f|
  [f.sub(/\.[^.\/]*\Z/, "")[/\d*\Z/].to_i, File.binread(f)]
}.sort_by{ |f| f[0] }.to_h

# Compare files
t = Time.now
step = 10000
size = files.map{ |f| f[1].size }.min.to_i
if range_end > 0 then size = [size, range_end].min end
offset = range_start
puts(" Offset" + files.map{ |f| " | " + f[0].to_s.rjust(3, " ") }.join)
puts("-------" + files.map{ |f| "------" }.join)
while offset < size do
  # Skip big equal chunks of size 'step'
  if offset + step < size && offset % step == 0
    if files.map{ |f| f[1][offset..offset + step] }.uniq.size == 1
      offset += step
      next
    end
  end
  # Compare byte by byte
  byte = files.first[1][offset]
  files.each{ |f|
    if f[1][offset] != byte
      puts(
        offset.to_s(16).rjust(7, " ") + files.map{ |f|
          " | " + f[1][offset].ord.to_s.rjust(3, " ")
        }.join
      )
      offset += 1
      next
    end
  }
  offset += 1
end

puts("Time elapsed: " + (1000 * (Time.now - t)).round(3).to_s + " milliseconds.")
