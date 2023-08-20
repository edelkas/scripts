if !File.file?('nprofile')
  puts "Didn't find nprofile"
  gets
  exit
end

f = File.binread('nprofile')

val = "\xFF\xFF\xFF\xFF".b
o = 0x80D320 + 36
20000.times.each{ |l| f[o...o + 4] = val; o += 48 }
o = 0x8F7920 + 36
4000.times.each{ |l| f[o...o + 4] = val; o += 48 }
o = 0x926720 + 36
800.times.each{ |l| f[o...o + 4] = val; o += 48 }

File.binwrite('nprofile', f)
puts "Done"
gets
