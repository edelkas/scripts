require 'gruff'

# Constants
palettes = [
  "BASIC", "F7200", "acid", "airline", "birthday cake", "blueprint", "bordeaux",
  "chemical", "chococherry", "classic", "clean", "console", "disassembly",
  "dorado", "dusk", "epaper", "epaper invert", "evening", "galactic",
  "gothmode", "holopshere", "hot", "infographics", "invert", "kicks",
  "lightcycle", "m", "metoro", "midnight", "minus", "mir", "mono", "moonbase",
  "neptune", "oceanographer", "okinami", "orbit", "pale", "papier",
  "papier invert", "party", "pinku", "plus", "poseidon", "pulse", "quench",
  "replicant", "retro", "shift", "shock", "simulator", "solarized dark",
  "solarized light", "supernavy", "toxin", "vasquez", "virtual", "vivid",
  "wizard", "yeti", "pumpkin", "witchy", "argon", "autumn", "berry",
  "bloodmoon", "brink", "cacao", "champagne", "concrete", "cowboy", "dagobah", 
  "debugger", "delicate", "desert world", "elephant", "florist", "formal", 
  "gatecrasher", "grapefrukt", "grappa", "gunmetal", "hazard", "heirloom",
  "hope", "hyperspace", "ice world", "incorporated", "jaune", "juicy", "lab",
  "lava world", "lemonade", "lichen", "line", "machine", "mustard", "mute",
  "nemk", "neutrality", "noctis", "petal", "PICO-8", "porphyrous", "QDUST",
  "regal", "rust", "sakura", "sinister", "starfighter", "sunset", "synergy",
  "talisman", "toothpaste", "TR-808", "tycho", "vectrex", "vintage", "void",
  "waka", "wyvern", "xenon", "powder", "CUSTOM"
]
n_official = 123
n_custom = 100
offset_official = 45137
offset_custom = 46367
step = 10

# Read palette usage info from savefile
file = File.binread("nprofile")
times = (0..n_official - 1).to_a.map{ |i|
  file[offset_official + i * step..offset_official + (i + 1) * step - 1].scan(/./m).map{ |c|
    c.unpack('H*')[0].to_i(16)
  }
}.map{ |s| (86400 * s[0] + 3600 * s[1] + 60 * s[2] + s[3]).to_f / 3600 }
custom = (0..n_custom - 1).to_a.map{ |i|
  file[offset_custom + i * step..offset_custom + (i + 1) * step - 1].scan(/./m).map{ |c|
    c.unpack('H*')[0].to_i(16)
  }
}.map{ |s| (86400 * s[0] + 3600 * s[1] + 60 * s[2] + s[3]).to_f / 3600 }.reduce(:+)
times.push(custom)
sum = times.sum

# Bar plot
subdivisions = 10
g = Gruff::SideBar.new('800x2400')
g.title = 'Palette Usage (Hours)'
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
g.data('Palettes', times)
g.labels = (0..n_official).to_a.map{ |i|
  [i, palettes[i] + " (%02.3f)" % times[i]]
}.to_h
#g.y_axis_increment = times.max.to_f / subdivisions
g.marker_count = 10
g.maximum_value = times.max
g.minimum_value = 0
#g.y_axis_label = "Palette"
#g.x_axis_label = "Hours"
g.write('palette_usage.png')

# Pie chart plot
class CustomLabeledPie < Gruff::Pie
  def data(name, data_points = [], options = {})
    super(name, data_points, options[:color])
    @data.each { |data_array| data_array << options[:label] }
  end
  private
  def slice_class
    CustomLabeledSlice
  end
  class CustomLabeledSlice < ::Gruff::Pie::PieSlice
    def label
      data_array[3] || super
    end
  end
end
CustomLabeledPie.new(800).tap do |h|
  h.title = 'Palette Usage (Hours)'
  h.hide_legend = true
  h.theme = Gruff::Themes::PASTEL
  (0..n_official).each{ |i|
    h.data(palettes[i], times[i], :label => (times[i].to_f / sum > 0.01 ? palettes[i] : ""))
  }
  h.labels = (0..n_official).to_a.map{ |i| [i, palettes[i]] }
  h.write('palette_usage_pie.png')
end
