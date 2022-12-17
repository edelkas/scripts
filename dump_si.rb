# Constants
o_l = "80D320".to_i(16)
o_e = "8F7920".to_i(16)
n_l = 3120
n_e = 600
d = 48
$limit = 3*10**6

# Map episode and level names to IDs
def ids(tab, offset, n, ep, x)
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

ids_e = (0..n_e - 1).to_a.map{ |e| "" }
ids("SI", 0, 5, true, false).each{ |k, v| ids_e[k] = v }
ids("S", 120, 20, true, true).each{ |k, v| ids_e[k] = v }
ids("SL", 240, 20, true, true).each{ |k, v| ids_e[k] = v }
ids("SU", 480, 20, true, true).each{ |k, v| ids_e[k] = v }
ids_e = ids_e.each_with_index.map{ |e, i| [i, e] }.to_h.select{ |i, e| e != "" }

ids_l = (0..n_l - 1).to_a.map{ |l| "" }
ids("SI", 0, 5, false, false).each{ |k, v| ids_l[k] = v }
ids("S", 600, 20, false, true).each{ |k, v| ids_l[k] = v }
ids("SL", 1200, 20, false, true).each{ |k, v| ids_l[k] = v }
ids("?", 1800, 20, true, true).each{ |k, v| ids_l[k] = v }
ids("SU", 2400, 20, false, true).each{ |k, v| ids_l[k] = v }
ids("!", 3000, 20, true, true).each{ |k, v| ids_l[k] = v }
ids_l = ids_l.each_with_index.map{ |l, i| [i, l] }.to_h.select{ |i, l| l != "" }

# Parse savefile
def _unpack(bytes)
  if bytes.is_a?(Array) then bytes = bytes.join end
  bytes.unpack('H*')[0].scan(/../).reverse.join.to_i(16)
end

def _parse(r)
  s = _unpack($file[r][36..39])
  t = _unpack($file[r][40..43])
  [_unpack($file[r][0..3]), _unpack($file[r][20..23]), _unpack($file[r][4..7]), 
   _unpack($file[r][12..15]) + _unpack($file[r][16..19]), _unpack($file[r][24..27]),
   s > $limit ? 0 : ("%.3f" % (s.to_f / 1000)), t > $limit ? "-" : t]
end

$file = File.binread("nprofile")

# Status: Locked (0), unlocked (1), completed (2).
header = ["Name", "ID", "Status", "Attempts", "Successes", "Gold", "Score", "Rank"].join(",")
data_l = ids_l.map{ |id, l|
  _parse((o_l + id * d..o_l + (id + 1) * d - 1)).unshift(ids_l[id]).join(",")
}.join("\n")
data_e = ids_e.map{ |id, e|
  _parse((o_e + id * d..o_e + (id + 1) * d - 1)).unshift(ids_e[id]).join(",")
}.join("\n")

# Dump data.
File.write("data_dump.csv", [header, data_l, data_e].join("\n"))

