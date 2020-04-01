require 'svggraph'

x_axis = ['1-10', '10-30', '30-50', '50-70', 'older']
options = {
  :width             => 640,
  :height            => 300,
  :stack             => :side,  # the stack option is valid for Bar graphs only
  :fields            => x_axis,
  :graph_title       => "Level attempts",
  :show_graph_title  => true,
  :show_x_title      => true,
  :x_title           => 'Attempts',
  :show_y_title      => true,
  :y_title           => 'Level',
  :y_title_location  => :end,
  :rotate_x_labels   => false,
  :rotate_y_labels   => false,
  #:scale_divisions => 1,
  :scale_integers    => true,
  :no_css            => true
}
male_data   = [2, 4, 6, 4, 2]
g = SVG::Graph::BarHorizontal.new(options)
g.add_data({:data => male_data, :title => "Male"})
File.open('bar.svg', 'w') {|f| f.write(g.burn_svg_only)}
