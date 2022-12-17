require 'open-uri'
require 'json'

$n_l = 3120
$n_e = 600
$ids_l = {
  "SI" => (   0.. 124).to_a,
  "S"  => ( 600..1199).to_a,
  "SU" => (2400..2999).to_a,
  "SL" => (1200..1799).to_a,
  "?"  => (1800..1919).to_a,
  "!"  => (3000..3119).to_a
}
$ids_e = {
  "SI" => (  0.. 24).to_a,
  "S"  => (120..239).to_a,
  "SU" => (480..599).to_a,
  "SL" => (240..359).to_a
}
$raw_l = []
$raw_e = []

# Map level ID to level code
def _ids(tab, offset, n, ep, x)
  ret = (0..n - 1).to_a.product(("A".."E").to_a).map{ |s|
    tab + "-" + s[1].to_s + "-" + s[0].to_s.rjust(2,"0")
  }
  if x
    ret += (0..n - 1).to_a.map{ |s| tab + "-X-" + s.to_s.rjust(2,"0") }
  end
  if !ep
    ret = ret.map{ |e| (0..4).to_a.map{ |l| e + "-" + l.to_s.rjust(2,"0") } }.flatten
  end
  ret = ret.each_with_index.map{ |l, i| [offset + i, l] }.to_h
end

# Populate list with all level and episode IDs and codes
def list
  $raw_e = (0..$n_e - 1).to_a.map{ |e| "" }
  _ids("SI", 0, 5, true, false).each{   |k, v| $raw_e[k] = v }
  _ids("S", 120, 20, true, true).each{  |k, v| $raw_e[k] = v }
  _ids("SL", 240, 20, true, true).each{ |k, v| $raw_e[k] = v }
  _ids("SU", 480, 20, true, true).each{ |k, v| $raw_e[k] = v }
  $raw_e = $raw_e.each_with_index.map{ |e, i| [i, e, -1] }.select{ |i, e, r| e != "" }

  $raw_l = (0..$n_l - 1).to_a.map{ |l| "" }
  _ids("S", 600, 20, false, true).each{   |k, v| $raw_l[k] = v }
  _ids("SI", 0, 5, false, false).each{    |k, v| $raw_l[k] = v }
  _ids("SL", 1200, 20, false, true).each{ |k, v| $raw_l[k] = v }
  _ids("?", 1800, 20, true, true).each{   |k, v| $raw_l[k] = v }
  _ids("SU", 2400, 20, false, true).each{ |k, v| $raw_l[k] = v }
  _ids("!", 3000, 20, true, true).each{   |k, v| $raw_l[k] = v }
  $raw_l = $raw_l.each_with_index.map{ |l, i| [i, l, -1] }.select{ |i, l, r| l != "" }
end

def download(id, i, ep = false)
  att ||= 0
  ret = URI.open("https://dojo.nplusplus.ninja/prod/steam/get_scores?steam_id=#{id}&steam_auth=&#{ep ? "episode" : "level"}_id=#{i}&qt=1").read
  if ret == '-1337'
    print("The Steam ID is not active, please open N++.\n")
    raise
  end
  return JSON.parse(ret)['scores'].map{ |s| s['rank'] }.max
rescue
  (att += 1) < $retries ? retry : (print("Server down, retry again later.\n"); return -1)
end

def download_all
  print("Introduce your SteamID64: ")
  id = STDIN.gets.chomp.to_i
  ok = true
  t = Time.now
  sz = $raw_e.size

  $raw_e.take(0).each_with_index{ |e, i|
    rank = download(id, e[0], true)
    if !rank.nil? && rank >= 0
      e[2] = rank
    else
      ok = false
    end
    print "Downloading episode #{e[1]} (#{i + 1} / #{sz}) [Rank: #{e[2]}]...   \r"
  }
  puts "" unless sz == 0
  message = ok ? "successfully" : "partially"
  print("Scores downloaded #{message}, time: " + (1000 * (Time.now - t)).round(3).to_s + " ms.\n")
end

def export
  out = ""
  $ids_e.each{ |tab, ids|
    5.times.each{ |row|
      $raw_e.select{ |i, e, r| i % 5 == row && ids.include?(i) }.map{ |e|  }
    }
  }
  puts "Ranks exported to 'list.txt'"
end

def main
  list
  download_all
  export
end

main


