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

names_l = (0...3120).to_a.map{ |l| "" }
_ids("S", 600, 20, false, true).each{ |k, v| names_l[k] = v }
_ids("SI", 0, 5, false, false).each{ |k, v| names_l[k] = v }
_ids("SL", 1200, 20, false, true).each{ |k, v| names_l[k] = v }
_ids("?", 1800, 20, true, true).each{ |k, v| names_l[k] = v }
_ids("SU", 2400, 20, false, true).each{ |k, v| names_l[k] = v }
_ids("!", 3000, 20, true, true).each{ |k, v| names_l[k] = v }
names_l = names_l.each_with_index.map{ |l, i| [i, l] }.to_h.select{ |i, l| l != "" }

rows = [['SI', 0],['S',600],['S2',2400],['SL',1200],['SS',1800],['SS2',3000]].map{ |tab, id|
  Dir.entries(tab).select{ |f| File.file?("#{tab}/#{f}") }.sort.each_with_index.map{ |f, i|
    file = File.binread("#{tab}/#{f}")
    print names_l[id + i].ljust(80, ' ') + "\r"
    if file.size < 0xB8 + 966 + 80
      nil
    else
      [names_l[id + i], *file[0xB8+966...0xB8+966+2*29].unpack('S<*')].join(',')
    end
  }.compact.join("\n")
}.join("\n")

header = [
  '', 'Ninja', 'Mine', 'Gold', 'Exit door', 'Exit switch', 'Regular door',
  'Locked door', 'Locked switch', 'Trap door', 'Trap switch', 'Launchpad',
  'Oneway', 'Chaingun drone', 'Laser drone', 'Zap drone', 'Seeker drone',
  'Floorguard', 'Bounce block', 'Gauss', 'Rocket', 'Thwump', 'Toggle mine',
  'Evil ninja', 'Laser turret', 'Boost', 'Deathball', 'Microdrone', 'Mini',
  'Shove thwump'
].join(",")

content = [header, rows].join("\n")
File.binwrite('npp_object_counts.csv', content)

