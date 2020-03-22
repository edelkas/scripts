#!/usr/bin/env ruby
file = File.binread("nprofile")
file[2584] = [ARGV[0].to_i.to_s(16).rjust(2,"0")].pack('H*')
File.binwrite("nprofile",file)
