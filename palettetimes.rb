require 'gruff'

file = File.binread("nprofile")
offset = 45137
step = 10
times = (0..20).to_a.map{ |i|
  file[offset + i * step..offset + (i + 1) * step - 1].scan(/./m).map{ |c|
    c.unpack('H*')[0].to_i(16)
  }
}.map{ |s| s[3] }

g = Gruff::Bar.new(1920)
g.title = 'Palette Usage'
g.hide_legend = true
g.marker_font_size = 12
g.theme = {
  :colors => ['#12a702'],
  :marker_color => '#dddddd',
  :font_color => 'black',      
  :background_colors => 'white'
}
g.data('Times', times)
g.labels = (0..20).to_a.map{ |s| [s, "aaaaaaa"] }.to_h
g.maximum_value = 60
g.minimum_value = 0
g.write('palette_usage.png')
