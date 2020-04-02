# To use, install the svg-graph gem:
# Linux: sudo gem install svg-graph

require 'svggraph'

# Constants
o_l = "80D320".to_i(16)
o_e = "8F7920".to_i(16)
n_l = 3120
n_e = 600
d = 48
$limit_l = 2165
$limit_e = 385
step = 20

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

# Read attempts info from savefile
def _unpack(bytes)
  if bytes.is_a?(Array) then bytes = bytes.join end
  bytes.unpack('H*')[0].scan(/../).reverse.join.to_i(16)
end
file = File.binread("nprofile")

data_l = ids_l.map{ |id, l|
  r = (o_l + id * d..o_l + (id + 1) * d - 1)
  [_unpack(file[r][4..7]), ids_l[id]]
}.each_slice(step).to_a.map{ |s| [s.map{ |s| s[0] }.sum.to_f / step, ""] }
total_l = step * data_l.sum{ |s| s[0] }
data_l = data_l.take($limit_l)

data_e = ids_e.map{ |id, e|
  r = (o_e + id * d..o_e + (id + 1) * d - 1)
  [_unpack(file[r][4..7]), ids_e[id]]
}.each_slice(step).to_a.map{ |s| [s.map{ |s| s[0] }.sum.to_f / step, ""] }
total_e = step * data_e.sum{ |s| s[0] }
data_e = data_e.take($limit_e)

# Bar plot (SVG)
def create_svg(filename, title, limit, x, y, data, labels)
  options = {
    :width             => 2000,
    :height            => 500,
    :stack             => :side,  # the stack option is valid for Bar graphs only
    :fields            => (0..limit - 1).to_a.map{ |s| "" },
    :graph_title       => title,
    :show_graph_title  => true,
    :show_x_title      => true,
    :x_title           => x,
    :show_y_title      => true,
    :y_title           => y,
    :y_title_location  => :end,
    :rotate_x_labels   => false,
    :rotate_y_labels   => false,
    :scale_divisions   => (data.max.to_f / 6).round,
    :scale_integers    => true,
    :no_css            => true,
    :bar_gap           => false,
    :show_data_values  => false,
  }
  g = SVG::Graph::Bar.new(options)
  g.add_data({:data => data, :title => "Data"})
  File.open(filename, 'w') {|f| f.write(g.burn_svg_only)}
end

svg1 = create_svg('attempts_smooth_levels.svg', "Level attempts (Total: #{total_l}) Smoothing: #{step}", $limit_l / step, 'Attempts', 'Level', data_l.map{ |s| s[0] }, data_l.map{ |s| s[1] }.reverse)
svg2 = create_svg('attempts_smooth_episodes.svg', "Episode attempts (Total: #{total_e}) Smoothing: #{step}", $limit_e / step, 'Attempts', 'Episode', data_e.map{ |s| s[0] }, data_e.map{ |s| s[1] }.reverse)
