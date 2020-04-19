files = Dir.entries(Dir.pwd).select{ |f| File.file?(f) }.sort.join("\n")
folder = File.basename(Dir.pwd).tr(" ", "_") + ".m3u"
File.write(folder, file)
