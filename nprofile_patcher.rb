require 'open-uri'
require 'json'

UPDATE_HIGHER = false # Updates local scores with server scores even if they're higher locally

# Constants
$o_l = "80D320".to_i(16)
$o_e = "8F7920".to_i(16)
$n_l = 3120
$n_e = 600
$d = 48
$l = 3000
$retries = 50000
$ids_l = {
  "SI" => (   0.. 124).to_a,
  "S"  => ( 600..1199).to_a,
  "SU" => (2400..2999).to_a,
  "SL" => (1200..1799).to_a,
  "?"  => (1800..1919).to_a,
  "!"  => (3000..3119).to_a
}
$ids_e = {
  "SI" => (  0.. 24).to_a,
  "S"  => (120..239).to_a,
  "SU" => (480..599).to_a,
  "SL" => (240..359).to_a
}

# State variables
$raw_l = []
$raw_e = []
$lvls = {}
$eps = {}
$errors = []

# To use this you need to send either a matrix or :sep
def make_table(rows, sep_x = "=", sep_y = "|", sep_i = "x")
  text_rows = rows.select{ |r| r.is_a?(Array) }
  count = text_rows.map(&:size).max
  rows.each{ |r| if r.is_a?(Array) then r << "" while r.size < count end }
  widths = (0..count - 1).map{ |c| text_rows.map{ |r| r[c].to_s.length }.max }
  sep = widths.map{ |w| sep_i + sep_x * (w + 2) }.join + sep_i + "\n"
  table = sep.dup
  rows.each{ |r|
    if r == :sep
      table << sep
    else
      r.each_with_index{ |s, i|
        table << sep_y + " " + (s.is_a?(Numeric) ? s.to_s.rjust(widths[i], " ") : s.to_s.ljust(widths[i], " ")) + " "
      }
      table << sep_y + "\n"
    end
  }
  table << sep
  return table
end

def r_l(i) ($o_l + i * $d..$o_l + (i + 1) * $d - 1) end
def r_e(i) ($o_e + i * $d..$o_e + (i + 1) * $d - 1) end

def combine_r(r1, r2)
  (r1.begin + r2.begin .. r1.begin + r2.end)
end

def _ids(tab, offset, n, ep, x)
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

def _pack(n, size)
  n.to_s(16).rjust(2 * size, "0").scan(/../).reverse.map{ |b| [b].pack('H*')[0] }.join.force_encoding("ascii-8bit")
end

def _unpack(bytes)
  if bytes.is_a?(Array) then bytes = bytes.join end
  bytes.unpack('H*')[0].scan(/../).reverse.join.to_i(16)
end

def is_completed(s)
  s[4] != 0 || s[5] != 0 || s[6] == 2 || s[7] != 0 || s[8] != 0 || s[11] < 20 || s[12] < 10**9
end

def update_scores
  $lvls = {
    :scored => {
      :uncompleted => $raw_l.select{ |s| s[10] < 1000 * $l && !is_completed(s) },
      :completed => $raw_l.select{ |s| s[10] < 1000 * $l && is_completed(s) }
    },
    :unscored => {
      :uncompleted => $raw_l.select{ |s| s[10] > 1000 * $l && !is_completed(s) },
      :completed => $raw_l.select{ |s| s[10] > 1000 * $l && is_completed(s) }
    }
  }
  $eps = {
    :scored => {
      :uncompleted => $raw_e.select{ |s| s[10] < 1000 * $l && !is_completed(s) },
      :completed => $raw_e.select{ |s| s[10] < 1000 * $l && is_completed(s) }
    },
    :unscored => {
      :uncompleted => $raw_e.select{ |s| s[10] > 1000 * $l && !is_completed(s) },
      :completed => $raw_e.select{ |s| s[10] > 1000 * $l && is_completed(s) }
    }
  }
end

def parse_savefile
  # Map episode and level names to IDs
  names_e = (0..$n_e - 1).to_a.map{ |e| "" }
  _ids("SI", 0, 5, true, false).each{ |k, v| names_e[k] = v }
  _ids("S", 120, 20, true, true).each{ |k, v| names_e[k] = v }
  _ids("SL", 240, 20, true, true).each{ |k, v| names_e[k] = v }
  _ids("SU", 480, 20, true, true).each{ |k, v| names_e[k] = v }
  names_e = names_e.each_with_index.map{ |e, i| [i, e] }.to_h.select{ |i, e| e != "" }

  names_l = (0..$n_l - 1).to_a.map{ |l| "" }
  _ids("S", 600, 20, false, true).each{ |k, v| names_l[k] = v }
  _ids("SI", 0, 5, false, false).each{ |k, v| names_l[k] = v }
  _ids("SL", 1200, 20, false, true).each{ |k, v| names_l[k] = v }
  _ids("?", 1800, 20, true, true).each{ |k, v| names_l[k] = v }
  _ids("SU", 2400, 20, false, true).each{ |k, v| names_l[k] = v }
  _ids("!", 3000, 20, true, true).each{ |k, v| names_l[k] = v }
  names_l = names_l.each_with_index.map{ |l, i| [i, l] }.to_h.select{ |i, l| l != "" }

  # Read info from savefile
  return false if !File.file?("nprofile")
  file = File.binread("nprofile")
  $raw_l = names_l.map{ |id, l|
    [
      names_l[id], id, _unpack(file[r_l(id)][4..7]), _unpack(file[r_l(id)][8..11]),
      _unpack(file[r_l(id)][12..15]), _unpack(file[r_l(id)][16..19]),
      _unpack(file[r_l(id)][20..23]), _unpack(file[r_l(id)][24..27]),
      _unpack(file[r_l(id)][28..31]), _unpack(file[r_l(id)][32..35]),
      _unpack(file[r_l(id)][36..39]), _unpack(file[r_l(id)][40..43]),
      _unpack(file[r_l(id)][44..47])
    ]
  }
  $raw_e = names_e.map{ |id, e|
    [
      names_e[id], id, _unpack(file[r_e(id)][4..7]), _unpack(file[r_e(id)][8..11]),
      _unpack(file[r_e(id)][12..15]), _unpack(file[r_e(id)][16..19]),
      _unpack(file[r_e(id)][20..23]), _unpack(file[r_e(id)][24..27]),
      _unpack(file[r_e(id)][28..31]), _unpack(file[r_e(id)][32..35]),
      _unpack(file[r_e(id)][36..39]), _unpack(file[r_e(id)][40..43]),
      _unpack(file[r_e(id)][44..47])
    ]
  }

  # Gather relevant stats
  update_scores
  return true
end

def parse_errors
  $errors = []
  if $lvls[:scored][:uncompleted].size != 0
    $errors << ["Found #{$lvls[:scored][:uncompleted].size.to_s} scored uncompleted levels.", $lvls[:scored][:uncompleted]]
  end
  if $lvls[:unscored][:completed].size != 0
    $errors << ["Found #{$lvls[:unscored][:completed].size.to_s} unscored completed levels.", $lvls[:unscored][:completed]]
  end
  if $raw_l.select{ |s| s[6] > 2 }.size > 0
    $errors << ["Found #{$raw_l.select{ |s| s[6] > 2 }.size.to_s} levels with incorrect state (neither locked, unlocked nor beaten).", $raw_l.select{ |s| s[6] > 2 }.size]
  end
  if $eps[:scored][:uncompleted].size != 0
    $errors << ["Found #{$eps[:scored][:uncompleted].size.to_s} scored uncompleted episodes.", $eps[:scored][:uncompleted]]
  end
  if $eps[:unscored][:completed].size != 0
    $errors << ["Found #{$eps[:unscored][:completed].size.to_s} unscored completed episodes.", $eps[:unscored][:completed]]
  end
  if $raw_e.select{ |s| s[6] > 2 }.size > 0
    $errors << ["Found #{$raw_e.select{ |s| s[6] > 2 }.size.to_s} episodes with incorrect state (neither locked, unlocked nor beaten).", $raw_e.select{ |s| s[6] > 2 }.size]
  end
end

def print_usage
  puts "DESCRIPTION: A tool to analyze and patch errors in N++'s PC savefile."
  #puts "USAGE: ruby nprofile_patcher.rb [ARGUMENT]"
  puts "COMMANDS:"
  puts "     scores - Shows your total level and episode scores."
  puts "     update - Update all scores in savefile."
  puts "       list - Lists all missing scores."
  puts "     errors - Lists only erroneous scores."
  puts "      patch - Correct missing scores in savefile."
  puts "    summary - Provides a summary and finds errors."
  puts "       exit - Exit the program."
  puts "NOTES:"
  puts "    * Place the savefile on the script's folder to use."
  puts "    * Please backup your savefile before patching it."
end

def print_errors
  print("\nFound #{$errors.map{ |e| e[1].size }.sum} erroneous scores:\n")
  $errors.each{ |e|
    print("* " + e[0] + "\n")
  }
end

def print_list(errors)
  parse_errors
  if errors
    $errors.each{ |e|
      puts "* " + e[0][0..-2] + ":"
      puts e[1].map{ |s| s[0] }.join(", ")
    }
  else
    puts "* All unscored levels: "
    puts ($lvls[:unscored][:completed].map{ |s| s[0] } + $lvls[:unscored][:uncompleted].map{ |s| s[0] }).join(", ")
    puts "* All unscored episodes: "
    puts ($eps[:unscored][:completed].map{ |s| s[0] } + $eps[:unscored][:uncompleted].map{ |s| s[0] }).join(", ")
  end
  return true
end

def print_tables
  t = []
  t << ["LEVELS", "Uncompleted", "Completed", "Total"]
  t << :sep
  t << [
    "Scored",
    $lvls[:scored][:uncompleted].size,
    $lvls[:scored][:completed].size,
    $lvls[:scored][:uncompleted].size + $lvls[:scored][:completed].size
  ]
  t << [
    "Unscored",
    $lvls[:unscored][:uncompleted].size,
    $lvls[:unscored][:completed].size,
    $lvls[:unscored][:uncompleted].size + $lvls[:unscored][:completed].size
  ]
  t << [
    "Total",
    $lvls[:scored][:uncompleted].size + $lvls[:unscored][:uncompleted].size,
    $lvls[:scored][:completed].size + $lvls[:unscored][:completed].size,
    $lvls[:scored][:uncompleted].size + $lvls[:scored][:completed].size + $lvls[:unscored][:uncompleted].size + $lvls[:unscored][:completed].size
  ]
  t << :sep
  t << ["EPISODES", "Uncompleted", "Completed", "Total"]
  t << :sep
  t << [
    "Scored",
    $eps[:scored][:uncompleted].size,
    $eps[:scored][:completed].size,
    $eps[:scored][:uncompleted].size + $eps[:scored][:completed].size
  ]
  t << [
    "Unscored",
    $eps[:unscored][:uncompleted].size,
    $eps[:unscored][:completed].size,
    $eps[:unscored][:uncompleted].size + $eps[:unscored][:completed].size
  ]
  t << [
    "Total",
    $eps[:scored][:uncompleted].size + $eps[:unscored][:uncompleted].size,
    $eps[:scored][:completed].size + $eps[:unscored][:completed].size,
    $eps[:scored][:uncompleted].size + $eps[:scored][:completed].size + $eps[:unscored][:uncompleted].size + $eps[:unscored][:completed].size
  ]
  puts make_table(t)
end

def download(id, i, ep = false)
  att ||= 0
  ret = URI.open("https://dojo.nplusplus.ninja/prod/steam/get_scores?steam_id=#{id}&steam_auth=&#{ep ? "episode" : "level"}_id=#{i}").read
  if ret == '-1337'
    print("The Steam ID is not active, please open N++.\n")
    (att += 1) < $retries ? raise : (return -1)
  end
  return JSON.parse(ret)['userInfo']
rescue
  (att += 1) < $retries ? retry : (print("Server down, retry again later.\n"); return -1)
end

def patch_score(id, file, s, ep)
  ret = download(id, s[1], ep)
  if ret == -1
    return false
  else
    return true if ret.nil?
    r = ep ? r_e(s[1]) : r_l(s[1])
    file[combine_r(r, 20..23)] = _pack(2                  , 4)
    if !UPDATE_HIGHER && s[10] < 1000 * $l && s[10] > ret['my_score'].to_i
      puts "Found correct unsubmitted score at #{s[0]}"
    else
      file[combine_r(r, 36..39)] = _pack(ret['my_score']    , 4)
    end
    file[combine_r(r, 40..43)] = _pack(ret['my_rank']     , 4)
    file[combine_r(r, 44..47)] = _pack(ret['my_replay_id'], 4)
    secrets = (1800..1919).to_a + (3000..3119).to_a
    if (s[1] + 1) % 5 != 0 && !secrets.include?(s[1] + 1)
      r = ep ? r_e(s[1] + 1) : r_l(s[1] + 1)
      file[combine_r(r, 20..23)] = _pack(1                , 4) unless _unpack(file[combine_r(r, 20..23)]) == 2
    end
    File.binwrite("nprofile", file)
    print "."
    return true
  end
end

def patch_scores
  return false if !File.file?("nprofile")
  file = File.binread("nprofile")
  print("Introduce your SteamID64: ")
  id = STDIN.gets.chomp.to_i
  ok = true
  t = Time.now

  $lvls[:scored][:uncompleted].each_with_index{ |s, i|
    print "Patching scored uncompleted levels... " + (i + 1).to_s + "/" + $lvls[:scored][:uncompleted].size.to_s + "   \r"
    file[combine_r(r_l(s[1]), 20..23)] = _pack(2,4)
  }
  File.binwrite("nprofile", file)
  puts "" unless $lvls[:scored][:uncompleted].size == 0

  $eps[:scored][:uncompleted].each_with_index{ |s, i|
    print "Patching scored uncompleted episodes... " + (i + 1).to_s + "/" + $eps[:scored][:uncompleted].size.to_s + "   \r"
    file[combine_r(r_e(s[1]), 20..23)] = _pack(2,4)
  }
  File.binwrite("nprofile", file)
  puts "" unless $eps[:scored][:uncompleted].size == 0

  $lvls[:unscored][:completed].each_with_index{ |s, i|
    ok = patch_score(id, file, s, false) && ok
    print "Patching unscored completed levels... " + (i + 1).to_s + "/" + $lvls[:unscored][:completed].size.to_s + "   \r"
  }
  puts "" unless $lvls[:unscored][:completed].size == 0

  $eps[:unscored][:completed].each_with_index{ |s, i|
    ok = patch_score(id, file, s, true) && ok
    print "Patching unscored completed episodes... " + (i + 1).to_s + "/" + $eps[:unscored][:completed].size.to_s + "   \r"
  }
  puts "" unless $eps[:unscored][:completed].size == 0

  update_scores
  message = ok ? "successfully" : "partially"
  print("nprofile patched #{message}, time: " + (1000 * (Time.now - t)).round(3).to_s + " ms.\n")
  return true
end

def patch_scores_full
  return false if !File.file?("nprofile")
  file = File.binread("nprofile")
  print("Introduce your SteamID64: ")
  id = STDIN.gets.chomp.to_i
  print("Introduce tab (SI, S, SU, SL, ?, !) or leave blank: ")
  tab = STDIN.gets.strip.upcase
  success = true
  t = Time.now

  $raw_l.select{ |s| $ids_l.key?(tab) ? $ids_l[tab].include?(s[1]) : true }.each_with_index{ |s, i|
    ok = patch_score(id, file, s, false) && ok
    print "Updating all levels..." + (i + 1).to_s + "/" + $raw_l.select{ |s| $ids_l.key?(tab) ? $ids_l[tab].include?(s[1]) : true }.size.to_s + "   \r"
  }
  puts ""

  $raw_e.select{ |s| $ids_e.key?(tab) ? $ids_e[tab].include?(s[1]) : true }.each_with_index{ |s, i|
    ok = patch_score(id, file, s, true) && ok
    print "Updating all episodes..." + (i + 1).to_s + "/" + $raw_e.select{ |s| $ids_e.key?(tab) ? $ids_e[tab].include?(s[1]) : true }.size.to_s + "   \r"
  }
  puts ""

  update_scores
  message = success ? "successfully" : "partially"
  print("nprofile updated #{message}, time: " + (1000 * (Time.now - t)).round(3).to_s + " ms.\n")
  return true
end

def print_scores
  levels = $ids_l.map{ |tab, ids|
    [tab, $lvls[:scored].map{ |k, v| v.select{ |l| ids.include?(l[1]) }.map{ |l| l[10] } }.flatten]
  }.to_h
  episodes = $ids_e.map{ |tab, ids|
    [tab, $eps[:scored].map{ |k, v| v.select{ |l| ids.include?(l[1]) }.map{ |l| l[10] } }.flatten]
  }.to_h
  tls = levels.map{ |tab, s| [tab, s.sum.to_f / 1000] }.to_h
  tes = episodes.map{ |tab, s| [tab, s.sum.to_f / 1000] }.to_h
  c_1 = levels.map{ |tab, s| s.sum.to_s(36).rjust(6, "0").reverse }.join
  c_2 = episodes.map{ |tab, s| s.sum.to_s(36).rjust(6, "0").reverse }.join
  c = c_1 + c_2
  t = []
  t << ["SCORES", "Levels", "Scores", "Episodes", "Scores"]
  t << :sep
  $ids_l.each{ |tab, r|
    t << [
      tab.to_s,
      ("%.3f" % tls[tab]).rjust(10, " "),
      levels[tab].size.to_s.rjust(4, " ") + " / " + r.size.to_s.rjust(4, " "),
      tes[tab].nil? ? "     0.000" : ("%.3f" % tes[tab]).rjust(10, " "),
      episodes[tab].nil? ? "  0 /   0" : episodes[tab].size.to_s.rjust(3, " ") + " / " + $ids_e[tab].size.to_s.rjust(3, " "),
    ]
  }
  t << :sep
  t << [
    "Total",
    ("%.3f" % tls.map{ |k, v| v }.sum).rjust(10, " "),
    $lvls[:scored].reduce(0){ |sum, s| sum += s[1].size }.to_s.rjust(4, " ") + " / 2165",
    ("%.3f" % tes.map{ |k, v| v }.sum).rjust(10, " "),
    $eps[:scored].reduce(0){ |sum, s| sum += s[1].size }.to_s.rjust(3, " ") + " / 385",
  ]
  puts make_table(t)
  puts("Checksum: " + c)
end

def main
  if ARGV.size == 0
    command = nil
  else
    command = ARGV[0]
  end
  loop do
    if command.nil?
      print("Introduce command: ")
      command = STDIN.gets.chomp
    end

    if !["patch", "update", "scores", "list", "summary", "exit", "quit", "patch-full", "errors"].include?(command)
      print_usage
      command = nil
      next
    end

    if ["exit", "quit"].include?(command)
      return
    end

    if !parse_savefile
      puts "nprofile file not found."
      puts "nprofile file needs to be on the script's folder, and with that name."
      command = nil
      next
    end

    case command
      when "summary"
        print_tables
        parse_errors
        print_errors
      when "list"
        if !print_list(false) then puts "An error happened." end
      when "errors"
        if !print_list(true) then puts "An error happened." end
      when "patch"
        if !patch_scores then puts "An error happened." end
      when "patch-full"
        if !patch_scores_full then puts "An error happened." end
      when "update"
        if !patch_scores_full then puts "An error happened." end
      when "scores"
        print_scores
      else
        print_usage
    end
    command = nil
  end
end

main
