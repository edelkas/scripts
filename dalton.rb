require 'svggraph'
require 'csv'
require 'date'

f = CSV.read("userlevels.csv")
d = f.select{ |l| l[1].to_i == 234533 }.map{ |l| l[5] }

date1 = DateTime.new(2019,11,1)
date2 = DateTime.new(2020,12,18)
dates = (date1..date2).to_a.map{ |d|
  s = d.to_s
  s = s[8..9] + "/" + s[5..6] + "/" + s[2..3]
  a = (0..23).to_a.map{ |h| s + " " + h.to_s.rjust(2,"0") }
}.flatten
maps = dates.map{ |date|
  d.select{ |m| m[0..10] == date }.size
}
dates.map!{ |date| date[9..10] == "00" ? date[0..7] : " " }

fields = (0..23).to_a.map(&:to_s)
amounts = (0..23).to_a.map{ |h| d.select{ |m| m[9..10] == h.to_s.rjust(2,"0") }.size }

g = SVG::Graph::Line.new( {
  :width => 800,
  :height => 200,
  :graph_title => "Dalton",
  :show_graph_title => true,
  :key => true,
  :stacked => true,
  :fields => fields,
  :area_fill => true,
  :scale_integers => false,
  #:min_scale_value => 1.5,
  :show_data_labels => false,
  :show_actual_values => false,
  :show_x_guidelines => false,
  :stagger_x_labels => true,
  :show_x_title => true,
  :x_title => "Time",
  :show_y_title => true,
  :y_title => "Maps",
  :y_title_text_direction => :bt,
  :show_lines => false,
  :add_popups => true,
  :round_popups => false,
  :x_axis_position   => 5,
  :y_axis_position   => 'apr',
})
g.add_data({:data => amounts, :title => "Data"})
File.open("dalton.svg", 'w') {|f| f.write(g.burn_svg_only)}
