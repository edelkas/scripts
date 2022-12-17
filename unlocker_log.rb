o_l = "80D320".to_i(16)
o_e = "8F7920".to_i(16)
n_l = 3120
n_e = 600
d = 48
$limit = 3*10**6

$file = File.binread("nprofile")
((0...25).to_a + (120...240).to_a + (240...360).to_a + (480...600).to_a).each{ |e|
  $file[o_e + e * d + 20] = "\x02".force_encoding("ASCII-8BIT")
  (0..4).each{ |l|
    $file[o_l + (5 * e + l) * d + 20] = "\x02".force_encoding("ASCII-8BIT")
  }
}
#[843, 847, 1927].each{ |id| $file[o_e + id * d + 20] = "\x01".force_encoding("ASCII-8BIT") }
File.binwrite("nprofileU", $file)

