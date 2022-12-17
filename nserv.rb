$target = "https://dojo.nplusplus.ninja"
$proxy  = "http://localhost:8124".ljust($target.length, "\x00")

def find_lib
  paths = {
    'windows' => "",
    'linux'   => "#{Dir.home}/.steam/steam/steamapps/common/N++/lib64/libnpp.so"
  }
  sys = 'linux'
  paths[sys]
end

def patch
  IO.binwrite(find_lib, IO.binread(find_lib).gsub($target, $proxy))
end

def depatch
  IO.binwrite(find_lib, IO.binread(find_lib).gsub($proxy, $target))
end

ARGV[0].to_i == 1 ? patch : depatch
