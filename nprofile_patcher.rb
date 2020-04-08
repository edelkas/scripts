require 'open-uri'
require 'json'

# Constants
$o_l = "80D320".to_i(16)
$o_e = "8F7920".to_i(16)
$n_l = 3120
$n_e = 600
$d = 48
$l = 3000

# State variables
$raw_l = []
$raw_e = []
$lvls = {}
$eps = {}
$errors = []

class String
  def black;          "\e[30m#{self}\e[0m" end
  def red;            "\e[31m#{self}\e[0m" end
  def green;          "\e[32m#{self}\e[0m" end
  def brown;          "\e[33m#{self}\e[0m" end
  def blue;           "\e[34m#{self}\e[0m" end
  def magenta;        "\e[35m#{self}\e[0m" end
  def cyan;           "\e[36m#{self}\e[0m" end
  def gray;           "\e[37m#{self}\e[0m" end

  def bg_black;       "\e[40m#{self}\e[0m" end
  def bg_red;         "\e[41m#{self}\e[0m" end
  def bg_green;       "\e[42m#{self}\e[0m" end
  def bg_brown;       "\e[43m#{self}\e[0m" end
  def bg_blue;        "\e[44m#{self}\e[0m" end
  def bg_magenta;     "\e[45m#{self}\e[0m" end
  def bg_cyan;        "\e[46m#{self}\e[0m" end
  def bg_gray;        "\e[47m#{self}\e[0m" end

  def bold;           "\e[1m#{self}\e[22m" end
  def italic;         "\e[3m#{self}\e[23m" end
  def underline;      "\e[4m#{self}\e[24m" end
  def blink;          "\e[5m#{self}\e[25m" end
  def reverse_color;  "\e[7m#{self}\e[27m" end
  def plain;      self.gsub /\e\[\d+m/, "" end
end

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

def update_scores
  $lvls = {
    :scored => {
      :locked => $raw_l.select{ |s| s[0] < 1000 * $l && s[2] == 0 },
      :unlocked => $raw_l.select{ |s| s[0] < 1000 * $l && s[2] == 1 },
      :beaten => $raw_l.select{ |s| s[0] < 1000 * $l && s[2] == 2 }
    },
    :unscored => {
      :locked => $raw_l.select{ |s| s[0] > 1000 * $l && s[2] == 0 },
      :unlocked => $raw_l.select{ |s| s[0] > 1000 * $l && s[2] == 1 },
      :beaten => $raw_l.select{ |s| s[0] > 1000 * $l && s[2] == 2 }
    }
  }
  $eps = {
    :scored => {
      :locked => $raw_e.select{ |s| s[0] < 1000 * $l && s[2] == 0 },
      :unlocked => $raw_e.select{ |s| s[0] < 1000 * $l && s[2] == 1 },
      :beaten => $raw_e.select{ |s| s[0] < 1000 * $l && s[2] == 2 }
    },
    :unscored => {
      :locked => $raw_e.select{ |s| s[0] > 1000 * $l && s[2] == 0 },
      :unlocked => $raw_e.select{ |s| s[0] > 1000 * $l && s[2] == 1 },
      :beaten => $raw_e.select{ |s| s[0] > 1000 * $l && s[2] == 2 }
    }
  }
end

def parse_savefile
  # Map episode and level names to IDs
  ids_e = (0..$n_e - 1).to_a.map{ |e| "" }
  _ids("SI", 0, 5, true, false).each{ |k, v| ids_e[k] = v }
  _ids("S", 120, 20, true, true).each{ |k, v| ids_e[k] = v }
  _ids("SL", 240, 20, true, true).each{ |k, v| ids_e[k] = v }
  _ids("SU", 480, 20, true, true).each{ |k, v| ids_e[k] = v }
  ids_e = ids_e.each_with_index.map{ |e, i| [i, e] }.to_h.select{ |i, e| e != "" }

  ids_l = (0..$n_l - 1).to_a.map{ |l| "" }
  _ids("S", 600, 20, false, true).each{ |k, v| ids_l[k] = v }
  _ids("SI", 0, 5, false, false).each{ |k, v| ids_l[k] = v }
  _ids("SL", 1200, 20, false, true).each{ |k, v| ids_l[k] = v }
  _ids("?", 1800, 20, true, true).each{ |k, v| ids_l[k] = v }
  _ids("SU", 2400, 20, false, true).each{ |k, v| ids_l[k] = v }
  _ids("!", 3000, 20, true, true).each{ |k, v| ids_l[k] = v }
  ids_l = ids_l.each_with_index.map{ |l, i| [i, l] }.to_h.select{ |i, l| l != "" }

  # Read info from savefile
  return false if !File.file?("nprofile")
  file = File.binread("nprofile")
  $raw_l = ids_l.map{ |id, l|
    [_unpack(file[r_l(id)][36..39]), ids_l[id], _unpack(file[r_l(id)][20..23]), id]
  }
  $raw_e = ids_e.map{ |id, e|
    [_unpack(file[r_e(id)][36..39]), ids_e[id], _unpack(file[r_e(id)][20..23]), id]
  }

  # Gather relevant stats
  update_scores
  return true
end

def parse_errors
  if $lvls[:scored][:locked].size != 0
    $errors << ["Found #{$lvls[:scored][:locked].size.to_s.red} scored locked levels.", $lvls[:scored][:locked]]
  end
  if $lvls[:scored][:unlocked].size != 0
    $errors << ["Found #{$lvls[:scored][:unlocked].size.to_s.red} scored unbeaten levels.", $lvls[:scored][:unlocked]]
  end
  if $lvls[:unscored][:beaten].size != 0
    $errors << ["Found #{$lvls[:unscored][:beaten].size.to_s.red} unscored beaten levels.", $lvls[:unscored][:beaten]]
  end
  if $raw_l.select{ |s| s[2] > 2 }.size > 0
    $errors << ["Found #{$raw_l.select{ |s| s[2] > 2 }.size.to_s.red} levels with incorrect state (neither locked, unlocked nor beaten).", $raw_l.select{ |s| s[2] > 2 }.size]
  end
  if $eps[:scored][:locked].size != 0
    $errors << ["Found #{$eps[:scored][:locked].size.to_s.red} scored locked episodes.", $eps[:scored][:locked]]
  end
  if $eps[:scored][:unlocked].size != 0
    $errors << ["Found #{$eps[:scored][:unlocked].size.to_s.red} scored unbeaten episodes.", $eps[:scored][:unlocked]]
  end
  if $eps[:unscored][:beaten].size != 0
    $errors << ["Found #{$eps[:unscored][:beaten].size.to_s.red} unscored beaten episodes.", $eps[:unscored][:beaten]]
  end
  if $raw_e.select{ |s| s[2] > 2 }.size > 0
    $errors << ["Found #{$raw_e.select{ |s| s[2] > 2 }.size.to_s.red} episodes with incorrect state (neither locked, unlocked nor beaten).", $raw_e.select{ |s| s[2] > 2 }.size]
  end
end

def print_usage
  puts "#{"DESCRIPTION".bold}: A tool to analyze and patch errors in N++'s PC savefile."
  puts "#{"USAGE".bold}: ruby nprofile_patcher.rb [#{"ARGUMENT".italic}]"
  puts "#{"ARGUMENTS".bold}:"
  puts "    summary - Provides a summary and finds errors."
  puts "       list - Lists erroneous scores."
  puts "      patch - Correct errors in savefile."
  puts "#{"NOTES".bold}:"
  puts "    * Place the savefile on the script's folder to use."
  puts "    * Please backup your savefile before patching it."
end

def print_errors
  print("\nFound #{$errors.map{ |e| e[1].size }.sum.to_s.red} erroneous scores:\n")
  $errors.each{ |e|
    print("* " + e[0] + "\n")
  }
end

def print_table
  t = []
  t << ["LEVELS", "Locked", "Unlocked", "Beaten", "Total"]
  t << :sep
  t << [
    "Scored",
    $lvls[:scored][:locked].size,
    $lvls[:scored][:unlocked].size,
    $lvls[:scored][:beaten].size,
    $lvls[:scored].reduce(0){ |sum, s| sum += s[1].size }
  ]
  t << [
    "Unscored",
    $lvls[:unscored][:locked].size,
    $lvls[:unscored][:unlocked].size,
    $lvls[:unscored][:beaten].size,
    $lvls[:unscored].reduce(0){ |sum, s| sum += s[1].size }
  ]
  t << [
    "Total",
    $lvls[:scored][:locked].size + $lvls[:unscored][:locked].size,
    $lvls[:scored][:unlocked].size + $lvls[:unscored][:unlocked].size,
    $lvls[:scored][:beaten].size + $lvls[:unscored][:beaten].size,
    $lvls[:scored].reduce(0){ |sum, s| sum += s[1].size } + $lvls[:unscored].reduce(0){ |sum, s| sum += s[1].size }
  ]
  t << :sep
  t << ["EPISODES", "Locked", "Unlocked", "Beaten", "Total"]
  t << :sep
  t << [
    "Scored",
    $eps[:scored][:locked].size,
    $eps[:scored][:unlocked].size,
    $eps[:scored][:beaten].size,
    $eps[:scored].reduce(0){ |sum, s| sum += s[1].size }
  ]
  t << [
    "Unscored",
    $eps[:unscored][:locked].size,
    $eps[:unscored][:unlocked].size,
    $eps[:unscored][:beaten].size,
    $eps[:unscored].reduce(0){ |sum, s| sum += s[1].size }
  ]
  t << [
    "Total",
    $eps[:scored][:locked].size + $eps[:unscored][:locked].size,
    $eps[:scored][:unlocked].size + $eps[:unscored][:unlocked].size,
    $eps[:scored][:beaten].size + $eps[:unscored][:beaten].size,
    $eps[:scored].reduce(0){ |sum, s| sum += s[1].size } + $eps[:unscored].reduce(0){ |sum, s| sum += s[1].size }
  ]
  puts make_table(t)
end

def download(id, i, ep = false)
  att ||= 0
  ret = open("https://dojo.nplusplus.ninja/prod/steam/get_scores?steam_id=#{id}&steam_auth=&#{ep ? "episode" : "level"}_id=#{i}").read
  if ret == '-1337'
    print("\nThe Steam ID is not active, please open N++ and patch again.\n")
    return -1
  end
  return JSON.parse(ret)['userInfo']
rescue
  (att += 1) < 2 ? retry : (print("Server down, retry again later."); return -1)
end

def patch_scores(types = [])
  return false if !File.file?("nprofile")
  file = File.binread("nprofile")
  print("Introduce your SteamID64: ")
  id = STDIN.gets.chomp.to_i
  success = true
  t = Time.now

  if types.empty? || types.include?(:lvl_scored_locked)
    print "Patching scored locked levels..."
    $lvls[:scored][:locked].each{ |s| file[combine_r(r_l(s[3]), 20..23)] = _pack(2,4) }
    File.binwrite("nprofile", file)
    print " patched.\n"
  end
  if types.empty? || types.include?(:lvl_scored_unlocked)
    print "Patching scored unbeaten levels..."
    $lvls[:scored][:unlocked].each{ |s| file[combine_r(r_l(s[3]), 20..23)] = _pack(2,4) }
    File.binwrite("nprofile", file)
    print " patched.\n"
  end
  if types.empty? || types.include?(:ep_scored_locked)
    print "Patching scored locked episodes..."
    $eps[:scored][:locked].each{ |s| file[combine_r(r_l(s[3]), 20..23)] = _pack(2,4) }
    File.binwrite("nprofile", file)
    print " patched.\n"
  end
  if types.empty? || types.include?(:ep_scored_unlocked)
    print "Patching scored unbeaten episodes..."
    $eps[:scored][:unlocked].each{ |s| file[combine_r(r_l(s[3]), 20..23)] = _pack(2,4) }
    File.binwrite("nprofile", file)
    print " patched.\n"
  end
  if types.empty? || types.include?(:lvl_unscored_beaten)
    print "Patching unscored beaten levels..."
    $lvls[:unscored][:beaten].each{ |s|
      ret = download(id, s[3])
      if ret == -1 || !success
        success = false
        break
      else
        next if ret.nil?
        file[combine_r(r_l(s[3]), 36..39)] = _pack(ret['my_score']    , 4)
        file[combine_r(r_l(s[3]), 40..43)] = _pack(ret['my_rank']     , 4)
        file[combine_r(r_l(s[3]), 44..47)] = _pack(ret['my_replay_id'], 4)
        File.binwrite("nprofile", file)
        print "."
      end
    }
    print " patched.\n" unless !success
  end
  if types.empty? || types.include?(:ep_unscored_beaten)
    print "Patching unscored beaten episodes..."
    $eps[:unscored][:beaten].each{ |s|
      ret = download(id, s[3], true)
      if ret == -1 || !success
        success = false
        break
      else
        next if ret.nil?
        file[combine_r(r_e(s[3]), 36..39)] = _pack(ret['my_score']    , 4)
        file[combine_r(r_e(s[3]), 40..43)] = _pack(ret['my_rank']     , 4)
        file[combine_r(r_e(s[3]), 44..47)] = _pack(ret['my_replay_id'], 4)
        File.binwrite("nprofile", file)
        print "."
      end
    }
    print " patched.\n" unless !success
  end

  update_scores
  message = success ? "successfully" : "partially"
  print("nprofile patched #{message}, time: " + (1000 * (Time.now - t)).round(3).to_s + " ms.\n")
  return true
end

def print_scores
  ids_l = {
    "SI" => (   0.. 124).to_a,
    "S"  => ( 600..1199).to_a,
    "SU" => (2400..2999).to_a,
    "SL" => (1200..1799).to_a,
    "?"  => (1800..1919).to_a,
    "!"  => (3000..3119).to_a
  }
  ids_e = {
    "SI" => (  0.. 24).to_a,
    "S"  => (120..239).to_a,
    "SU" => (480..599).to_a,
    "SL" => (240..359).to_a
  }
  levels = ids_l.map{ |tab, ids|
    [tab, $lvls[:scored].map{ |k, v| v.select{ |l| ids.include?(l[3]) }.map{ |l| l[0] } }.flatten]
  }.to_h
  episodes = ids_e.map{ |tab, ids|
    [tab, $eps[:scored].map{ |k, v| v.select{ |l| ids.include?(l[3]) }.map{ |l| l[0] } }.flatten]
  }.to_h
  tls = levels.map{ |tab, s| [tab, s.sum.to_f / 1000] }.to_h
  tes = episodes.map{ |tab, s| [tab, s.sum.to_f / 1000] }.to_h
  t = []
  t << ["SCORES", "Levels", "Scores", "Episodes", "Scores"]
  t << :sep
  ids_l.each{ |tab, r|
    t << [
      tab.to_s,
      ("%.3f" % tls[tab]).rjust(10, " "),
      levels[tab].size.to_s.rjust(4, " ") + " / " + r.size.to_s.rjust(4, " "),
      tes[tab].nil? ? "     0.000" : ("%.3f" % tes[tab]).rjust(10, " "),
      episodes[tab].nil? ? "  0 /   0" : episodes[tab].size.to_s.rjust(3, " ") + " / " + ids_e[tab].size.to_s.rjust(3, " "),
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
end

def main
  if !parse_savefile
    puts "nprofile file not found."
    puts "nprofile file needs to be on the script's folder, and with that name."
    return
  end
  if ARGV.size == 0
    print_usage
  else
    case ARGV[0]
      when "summary"
        print_table
        parse_errors
        print_errors
      when "list"
        parse_errors
        $errors.each{ |e|
          puts "* " + e[0][0..-2] + ":"
          puts e[1].map{ |s| s[1] }.join(", ")
        }
      when "patch"
        if !patch_scores
          puts "nprofile file not found."
          puts "nprofile file needs to be on the script's folder, and with that name."
          return
        end
      when "scores"
        print_scores
      else
        print_usage
    end
  end
end

main
