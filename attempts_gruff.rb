require 'gruff'

# Constants
o_l = "80D320".to_i(16)
o_e = "8F7920".to_i(16)
n_l = 3120
n_e = 600
d = 48
limit = 20

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

ids_l = (0..n_l - 1).to_a.map{ |l| "" }
ids("SI", 0, 5, false, false).each{ |k, v| ids_l[k] = v }
ids("S", 600, 20, false, true).each{ |k, v| ids_l[k] = v }
ids("SL", 1200, 20, false, true).each{ |k, v| ids_l[k] = v }
ids("?", 1800, 20, true, true).each{ |k, v| ids_l[k] = v }
ids("SU", 2400, 20, false, true).each{ |k, v| ids_l[k] = v }
ids("!", 3000, 20, true, true).each{ |k, v| ids_l[k] = v }

# Read attempts info from savefile
def _unpack(bytes)
  if bytes.is_a?(Array) then bytes = bytes.join end
  bytes.unpack('H*')[0].scan(/../).reverse.join.to_i(16)
end
file = File.binread("nprofile")

data_l = (0..n_l - 1).to_a.map{ |i|
  r = (o_l + i * d..o_l + (i + 1) * d - 1)
  [_unpack(file[r][4..7]), ids_l[i]]
}.sort_by{ |s| -s[0] }
total_l = data_l.sum{ |s| s[0] }
data_l = data_l.take(limit)

data_e = (0..n_e - 1).to_a.map{ |i|
  r = (o_e + i * d..o_e + (i + 1) * d - 1)
  [_unpack(file[r][4..7]), ids_e[i]]
}.sort_by{ |s| -s[0] }
total_e = data_e.sum{ |s| s[0] }
data_e = data_e.take(limit)

# Bar plot (PNG)
def setup(title, data)
  subdivisions = 10
  g = Gruff::SideBar.new('800x800')
  g.title = title
  g.font = 'ShareTechMono-Regular.ttf'
  g.hide_legend = true
  g.show_labels_for_bar_values = false
  g.hide_line_numbers = true
  g.marker_font_size = 16
  g.theme = {
    :colors => ['#12a702'],
    :marker_color => '#dddddd',
    :font_color => 'black',      
    :background_colors => 'white'
  }
  #g.y_axis_increment = data.max.to_f / subdivisions
  g.data('levels', data)
  g.marker_count = 10
  g.maximum_value = data.max
  g.minimum_value = 0
  g
end

g = setup("Level attempts (Total: #{total_l})", data_l.map{ |s| s[0] })
g.labels = (0..limit - 1).to_a.map{ |i|
  [i, data_l[i][1] + ("(%d)" % data_l[i][0]).rjust(7, " ")]
}.to_h
g.write('attempts_levels.png')

h = setup("Episode attempts (Total: #{total_e})", data_e.map{ |s| s[0] })
h.labels = (0..limit - 1).to_a.map{ |i|
  [i, data_e[i][1] + ("(%d)" % data_e[i][0]).rjust(7, " ")]
}.to_h
h.write('attempts_episodes.png')
