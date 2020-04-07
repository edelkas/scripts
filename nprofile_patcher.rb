# To use, install the svg-graph and terminal-table gems:
# Linux: sudo gem install svg-graph terminal-table

require 'terminal-table'

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
  table = Terminal::Table.new do |t|
    t.style = {border_x: "=", border_i: "x"}
    t << ["LEVELS", "Locked", "Unlocked", "Beaten", "Total"]
    t << :separator
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
    t << :separator
    t << ["EPISODES", "Locked", "Unlocked", "Beaten", "Total"]
    t << :separator
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
  end
  puts table
end

def patch_scores(types = [])
  t = Time.now
  return false if !File.file?("nprofile")
  file = File.binread("nprofile")

  if types.empty? || types.include?(:lvl_scored_locked)
    $lvls[:scored][:unlocked].each{ |s|
      file[combine_r(r_l(s[3]), 20..23)] = _pack(2,4)
    }
  end

  File.binwrite("nprofile", file)
  print("nprofile patched successfully, time: " + (1000 * (Time.now - t)).round(3).to_s + "ms.\n")
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
        patch_scores
      else
        print_usage
    end
  end
end

main
