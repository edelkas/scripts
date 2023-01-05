require 'net/http'
require 'socket'

EXPORT = false

$port   = 8124
$target = "https://dojo.nplusplus.ninja"
$proxy  = "http://localhost:#{$port}".ljust($target.length, "\x00")
$socket = nil
$count  = 0

def clear
  print "\r".ljust(80, ' ') + "\r"
end

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

def read(client)
  req = ""
  begin
    req << client.read_nonblock(16 * 1024)
  rescue Errno::EAGAIN
    retry if IO.select([client], nil, nil, 1)
  rescue
  end
  req
end

def clear_headers(http)
  http.delete('accept-encoding')
  http.delete('accept')
  http.delete('user-agent')
  http.delete('host')
  http.delete('content-length')
  http.delete('content-type')
  http
end

def log(line)
  method, path, protocol = line.split  
  puts "#{"%-4s" % method} #{path.split('?')[0].split('/')[-1]}"
end

def intercept(req)
  #IO.binread('query')
  forward(req)
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
  reqNew = clear_headers(reqNew)
  req.split("\r\n\r\n")[0].split("\r\n")[1..-1].map{ |h| h.split(": ") }.each{ |h|
    reqNew[h[0]] = h[1]
  }
  reqNew['host'] = $target[8..-1]
  reqNew.body = req.split("\r\n\r\n")[1..-1].join("\r\n\r\n")
  # Execute proxied request
  res = ""
  f = File.open("req2_#{$count}", "wb") if EXPORT
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.read_timeout = 2
  http.set_debug_output(f) if EXPORT
  res = http.start{ |http| http.request(reqNew) }
  f.close if EXPORT
  # Build proxied response
  status = "HTTP/1.1 #{res.code} #{res.msg}\r\n"
  headers = res.to_hash.map{ |k, v| "#{k}: #{v[0]}\r\n" }.join
  "#{status}#{headers}\r\n#{res.body}"
end

def startup
  patch
  $socket = TCPServer.new($port)
  puts 'Started'
end

def loop
  client = $socket.accept
  req = client.gets
  $count += 1
  log(req)
  method, path, protocol = req.split
  req << read(client)
  IO.binwrite("req1_#{$count}", req) if EXPORT
  if method == 'GET' && path.split('?')[0].split('/')[-1] == 'query_levels'
    res = intercept(req)
  else
    res = forward(req)
  end
  IO.binwrite("res_#{$count}", res) if EXPORT
  client.write(res)
  client.close
end

def shutdown
  clear
  depatch
  puts "Stopped"
  exit
end

trap 'INT' do shutdown end
startup
while true do loop end
