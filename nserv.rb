require 'byebug'
require 'net/http'
require 'socket'

$port   = 8124
$target = "https://dojo.nplusplus.ninja"
$proxy  = "http://localhost:#{$port}".ljust($target.length, "\x00")
$socket = nil

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
  puts 'Patched'
end

def depatch
  IO.binwrite(find_lib, IO.binread(find_lib).gsub($proxy, $target))
  puts 'Depatched'
end

def intercept
  IO.binread('query_hardest')
end

def forward(req)
  # Build proxied request
  method, path, protocol = req.split("\r\n")[0].split
  uri = URI.parse($target + path)
  case method.upcase
  when 'GET'
    reqNew = Net::HTTP::Get.new(uri)
  when 'POST'
    reqNew = Net::HTTP::Post.new(uri)
  else
    raise "Unknown HTTP method requested by N++"
  end
  req.split("\r\n\r\n")[0].split("\r\n")[1..-1].map{ |h| h.split(": ") }.each{ |h|
    reqNew[h[0]] = h[1]
  }
  reqNew['host'] = $target[8..-1]
  reqNew.body = req.split("\r\n\r\n")[1..-1].join("\r\n\r\n")
  # Execute proxied request
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, read_timeout: 5){ |http|
    http.request(reqNew)
  }
  # Build proxied response
  status = "HTTP/1.1 #{res.code} #{res.msg}\r\n"
  headers = res.to_hash.map{ |k, v| "#{k}: #{v[0]}\r\n" }.join
  res = "#{status}#{headers}\r\n#{res.body}"
  IO.binwrite('res', res)
  res
end

def startup
  patch
  $socket = TCPServer.new($port)
end

def loop
  client = $socket.accept
  req = client.gets
  method, path, protocol = req.split
  req << client.read
  IO.binwrite('req', req)
  if method == 'GET' && path.split('?')[0].split('/')[-1] == 'query_levels'
    res = intercept
  else
    res = forward(req)
  end
  client.write(res)
  client.close
end

def shutdown
  depatch
  $socket.close
end

trap 'INT' do shutdown end
startup
while true do loop end
