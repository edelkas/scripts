# Convert XLS to CSV first, make sure to quote all string cells and include
# entire formulas, not only values.

require 'csv'
require 'net/http'

LIMIT = 126

sheet = CSV.read('Community tab WIP.csv')
files = []

(1..LIMIT - 1).each{ |i|
  print("Downloading file #{i} / #{LIMIT - 1}...".ljust(80, " ") + "\r")
  url = sheet[i][1][/(https:\/\/.*)",/i, 1]
  file =  url.split("/").last
  if !files.include?(file)
    files << file
    res = Net::HTTP.get(URI.parse(url))
    File.binwrite("levels_raw/" + file, res)
  end
}
