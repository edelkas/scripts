# To use, install the svg-graph and terminal-table gems:
# Linux: sudo gem install svg-graph terminal-table

require 'svggraph'
require 'terminal-table'

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

raw_l = ids_l.map{ |id, l|
  r = (o_l + id * d..o_l + (id + 1) * d - 1)
  [_unpack(file[r][36..39]), ids_l[id], _unpack(file[r][20..23])]
}
data_l = raw_l.map{ |s| s[0] > 3000000 ? nil : s }.compact.sort_by{ |s| -s[0] }
total_l = data_l.sum{ |s| s[0] }.to_f / 1000
data_l = data_l.take(limit).map{ |s| [s[0].to_f / 1000, s[1], s[2]] }

raw_e = ids_e.map{ |id, e|
  r = (o_e + id * d..o_e + (id + 1) * d - 1)
  [_unpack(file[r][36..39]), ids_e[id], _unpack(file[r][20..23])]
}
data_e = raw_e.map{ |s| s[0] > 3000000 ? nil : s }.compact.sort_by{ |s| -s[0] }
total_e = data_e.sum{ |s| s[0] }.to_f / 1000
data_e = data_e.take(limit).map{ |s| [s[0].to_f / 1000, s[1], s[2]] }

# Gather relevant stats
lvls = {
  :scored => {
    :locked => raw_l.select{ |s| s[0] < 3000000 && s[2] == 0 },
    :unlocked => raw_l.select{ |s| s[0] < 3000000 && s[2] == 1 },
    :beaten => raw_l.select{ |s| s[0] < 3000000 && s[2] == 2 }
  },
  :unscored => {
    :locked => raw_l.select{ |s| s[0] > 3000000 && s[2] == 0 },
    :unlocked => raw_l.select{ |s| s[0] > 3000000 && s[2] == 1 },
    :beaten => raw_l.select{ |s| s[0] > 3000000 && s[2] == 2 }
  }
}
eps = {
  :scored => {
    :locked => raw_e.select{ |s| s[0] < 3000000 && s[2] == 0 },
    :unlocked => raw_e.select{ |s| s[0] < 3000000 && s[2] == 1 },
    :beaten => raw_e.select{ |s| s[0] < 3000000 && s[2] == 2 }
  },
  :unscored => {
    :locked => raw_e.select{ |s| s[0] > 3000000 && s[2] == 0 },
    :unlocked => raw_e.select{ |s| s[0] > 3000000 && s[2] == 1 },
    :beaten => raw_e.select{ |s| s[0] > 3000000 && s[2] == 2 }
  }
}

table = Terminal::Table.new do |t|
  t.style = {border_x: "=", border_i: "x"}
  t << ["LEVELS", "Locked", "Unlocked", "Beaten", "Total"]
  t << :separator
  t << [
    "Scored",
    lvls[:scored][:locked].size,
    lvls[:scored][:unlocked].size,
    lvls[:scored][:beaten].size,
    lvls[:scored].reduce(0){ |sum, s| sum += s[1].size }
  ]
  t << [
    "Unscored",
    lvls[:unscored][:locked].size,
    lvls[:unscored][:unlocked].size,
    lvls[:unscored][:beaten].size,
    lvls[:unscored].reduce(0){ |sum, s| sum += s[1].size }
  ]
  t << [
    "Total",
    lvls[:scored][:locked].size + lvls[:unscored][:locked].size,
    lvls[:scored][:unlocked].size + lvls[:unscored][:unlocked].size,
    lvls[:scored][:beaten].size + lvls[:unscored][:beaten].size,
    lvls[:scored].reduce(0){ |sum, s| sum += s[1].size } + lvls[:unscored].reduce(0){ |sum, s| sum += s[1].size }
  ]
  t << :separator
  t << ["EPISODES", "Locked", "Unlocked", "Beaten", "Total"]
  t << :separator
  t << [
    "Scored",
    eps[:scored][:locked].size,
    eps[:scored][:unlocked].size,
    eps[:scored][:beaten].size,
    eps[:scored].reduce(0){ |sum, s| sum += s[1].size }
  ]
  t << [
    "Unscored",
    eps[:unscored][:locked].size,
    eps[:unscored][:unlocked].size,
    eps[:unscored][:beaten].size,
    eps[:unscored].reduce(0){ |sum, s| sum += s[1].size }
  ]
  t << [
    "Total",
    eps[:scored][:locked].size + eps[:unscored][:locked].size,
    eps[:scored][:unlocked].size + eps[:unscored][:unlocked].size,
    eps[:scored][:beaten].size + eps[:unscored][:beaten].size,
    eps[:scored].reduce(0){ |sum, s| sum += s[1].size } + eps[:unscored].reduce(0){ |sum, s| sum += s[1].size }
  ]
end
puts table
puts lvls[:scored][:unlocked].map{ |e| e[1] }.join(", ")

# Bar plot (SVG)
def create_svg(filename, title, x, y, data, labels)
  options = {
    :width             => 800,
    :height            => 500,
    :stack             => :side,  # the stack option is valid for Bar graphs only
    :fields            => labels,
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
    :no_css            => true
  }
  g = SVG::Graph::BarHorizontal.new(options)
  g.add_data({:data => data, :title => "Data"})
  File.open(filename, 'w') {|f| f.write(g.burn_svg_only)}
end

svg1 = create_svg('scores_levels.svg', "Level scores (Total: #{total_l})", 'Attempts', 'Levels', data_l.map{ |s| s[0] }.reverse, data_l.map{ |s| s[1] }.reverse)
svg2 = create_svg('scores_episodes.svg', "Episode scores (Total: #{total_e})", 'Attempts', 'Levels', data_e.map{ |s| s[0] }.reverse, data_e.map{ |s| s[1] }.reverse)
