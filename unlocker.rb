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

$file = File.binread("nprofile")
data_l = ids_l.each{ |id, l|
  if (!(id.between?(1100,1199) || id.between?(1700,1799) || id.between?(2900,2999)))
    $file[o_l + id * d + 20] = "\x02".force_encoding("ASCII-8BIT")
  else
    $file[o_l + id * d + 20] = "\x01".force_encoding("ASCII-8BIT")
  end
  if (id.between?(600,724) || id.between?(2400,2524))
    $file[o_l + id * d + 24] = "\xFF".force_encoding("ASCII-8BIT")
  end
}
data_e = ids_e.each{ |id, e|
  if (!(id.between?(220,239) || id.between?(340,359) || id.between?(580,599)))
    $file[o_e + id * d + 20] = "\x02".force_encoding("ASCII-8BIT")
  else
    $file[o_e + id * d + 20] = "\x01".force_encoding("ASCII-8BIT")
  end
}
File.binwrite("nprofileU", $file)

