print "Folder name: "
tab = STDIN.gets.chomp

if !Dir.exist?(tab)
  puts "Folder #{tab} does not exist"
  exit
end

name = "#{tab}.csv"
File.binwrite(
  name,
  Dir.entries(tab).select{ |f| File.file?("#{tab}/#{f}") }.sort.map{ |f|
    file = File.binread("#{tab}/#{f}")
    if file.size < 0xB8 + 966 + 80
      nil
    else
      file[0xB8+966...0xB8+966+2*40].unpack('S<*').join(',')
    end
  }.compact.join("\n")
)

puts "Exported counts to #{name}"
