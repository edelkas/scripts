###############################################################################
#
# @desc:   This script generates a tab file ready to import to N++.
# @author: Eddy
# @date:   2020-Sep-28
# @update: 2025-Feb-24
#
# USAGE:
# 1) Put all levels in a folder called "levels", and nothing else inside.
# 2) Put script just outside that folder.
# 3) Run script using "ruby generate_tab.rb".
# 4) A file called "S.txt" (or a similar tab name) will be created.
# 5) Copy such file to "levels" folder of NPP folder.
#
###############################################################################

# <---------------------------------------------------------------------------->
#                             CONSTANTS AND TOOLS
# <---------------------------------------------------------------------------->

# FOLDER: Where the levels to be read are stored
# TAB:    Name of the tab to produce, should be SI, S, SU, SL, SS or SS2.
# PREFIX: Number of characters to crop from the beginning of the level names.
# SHORT:  What to do with level names which length is below PREFIX. true will
#         leave them unchanged, and false will change them to "empty_1",...
# SORT:   Sort level names based on prefix "X-0Y-Z"
FOLDER = "levels"
TAB    = "S"
PREFIX = 4
SHORT  = true
SORT   = false

# 'pref' is the drawing preference when for overlaps, the lower the better
# 'att' is the number of attributes they have in the old format (in the new one it's always 5)
# 'old' is the ID in the old format, '-1' if it didn't exist
# 'pal' is the index at which the colors of the object start in the palette image
OBJECTS = {
  0x00 => {name: 'ninja',              pref:  4, att: 2, old:  0, pal:  6},
  0x01 => {name: 'mine',               pref: 22, att: 2, old:  1, pal: 10},
  0x02 => {name: 'gold',               pref: 21, att: 2, old:  2, pal: 14},
  0x03 => {name: 'exit',               pref: 25, att: 4, old:  3, pal: 17},
  0x04 => {name: 'exit switch',        pref: 20, att: 0, old: -1, pal: 25},
  0x05 => {name: 'regular door',       pref: 19, att: 3, old:  4, pal: 30},
  0x06 => {name: 'locked door',        pref: 28, att: 5, old:  5, pal: 31},
  0x07 => {name: 'locked door switch', pref: 27, att: 0, old: -1, pal: 33},
  0x08 => {name: 'trap door',          pref: 29, att: 5, old:  6, pal: 39},
  0x09 => {name: 'trap door switch',   pref: 26, att: 0, old: -1, pal: 41},
  0x0A => {name: 'launch pad',         pref: 18, att: 3, old:  7, pal: 47},
  0x0B => {name: 'one-way platform',   pref: 24, att: 3, old:  8, pal: 49},
  0x0C => {name: 'chaingun drone',     pref: 16, att: 4, old:  9, pal: 51},
  0x0D => {name: 'laser drone',        pref: 17, att: 4, old: 10, pal: 53},
  0x0E => {name: 'zap drone',          pref: 15, att: 4, old: 11, pal: 57},
  0x0F => {name: 'chase drone',        pref: 14, att: 4, old: 12, pal: 59},
  0x10 => {name: 'floor guard',        pref: 13, att: 2, old: 13, pal: 61},
  0x11 => {name: 'bounce block',       pref:  3, att: 2, old: 14, pal: 63},
  0x12 => {name: 'rocket',             pref:  8, att: 2, old: 15, pal: 65},
  0x13 => {name: 'gauss turret',       pref:  9, att: 2, old: 16, pal: 69},
  0x14 => {name: 'thwump',             pref:  6, att: 3, old: 17, pal: 74},
  0x15 => {name: 'toggle mine',        pref: 23, att: 2, old: 18, pal: 12},
  0x16 => {name: 'evil ninja',         pref:  5, att: 2, old: 19, pal: 77},
  0x17 => {name: 'laser turret',       pref:  7, att: 4, old: 20, pal: 79},
  0x18 => {name: 'boost pad',          pref:  1, att: 2, old: 21, pal: 81},
  0x19 => {name: 'deathball',          pref: 10, att: 2, old: 22, pal: 83},
  0x1A => {name: 'micro drone',        pref: 12, att: 4, old: 23, pal: 57},
  0x1B => {name: 'alt deathball',      pref: 11, att: 2, old: 24, pal: 86},
  0x1C => {name: 'shove thwump',       pref:  2, att: 2, old: 25, pal: 88}
}
ROWS = 23
COLUMNS = 42

# for hex to dec conversion
class String
  def hd
    self.unpack('H*')[0].to_i(16)
  end
end

# for padding arrays
class Array
  def rjust(n, x); Array.new([0, n-length].max, x)+self end
  def ljust(n, x); dup.fill(x, length...n) end
end

# for producing stable sorting (ie. maintaining the order of elements in which
# the order is tied)
module Enumerable
  def stable_sort
    sort_by.with_index { |x, idx| [x, idx] }
  end

  def stable_sort_by
    sort_by.with_index { |x, idx| [yield(x), idx] }
  end
end

def parse_str(str)
  str.split("\x00")[0].bytes.reject{ |b| b < 32 || b >= 127 }.map(&:chr).join.force_encoding('UTF-8').scrub('').strip
end

# <---------------------------------------------------------------------------->
#                               PARSING MAPS
# <---------------------------------------------------------------------------->

# new - current map format, used by userlevels, attract files...
# old - old map format, used by Metanet levels
def parse_map(data: "", type: "new")
  if data.empty? then return end
  if type == "level" || type == "attract" then type = "new" end
  case type
  when "new"
    tiles = data[0..965].split(//).map{ |b| b.hd }.each_slice(COLUMNS).to_a
    object_counts = data[966..1045].scan(/../).map{ |s| s.reverse.hd }
    objects = data[1046..-1].scan(/.{5}/m).map{ |o| o.chars.map{ |e| e.hd } }
  when "old"
    data = data[8..-1]
    tiles = data[0..1931].scan(/../).map{ |b| b.reverse.to_i(16) }.each_slice(COLUMNS).to_a
    objs = data[1932..-1]
    objects = []
    OBJECTS.sort_by{ |id, o| o[:old] }.reject{ |id, o| o[:old] == -1 }.each{ |id, type|
      if objs.length < 4 then break end
      quantity = objs[0..3].scan(/../).map(&:reverse).join.to_i(16)
      objs[4 .. 3 + 2 * quantity * type[:att]].scan(/.{#{2 * type[:att]}}/).each{ |o|
        if ![3,6,8].include?(id) # everything else
          objects << [id] + o.scan(/../).map{ |att| att.reverse.to_i(16) }.ljust(4,0)
        else # door switches
          atts = o.scan(/../).map{ |att| att.reverse.to_i(16) }
          objects << [id] + atts[0..-3].ljust(4,0)  # door
          objects << [id + 1] + atts[-2..-1].ljust(4,0) # switch
        end
      }
      objs = objs[4 + 2 * quantity * type[:att]..-1]
    }
  end
  {tiles: tiles, objects: objects.stable_sort_by{ |o| o[0] }}
rescue
  #print("ERROR: Incorrect map data\n")
  return nil
end

# level - for files returned by the level editor (stored in "N++/levels")
# attract -  for death replay files (stored in "N++/attract")
# old - for files with Metanet levels (old format)
def parse_file(filename: "", type: "level")
  !filename.empty? ? file = File.binread(filename) : return
  case type
  when "level"
    mode = file[12].reverse.hd # game mode: 0 = solo, 1 = coop, 2 = race, 4 = unset
    title = parse_str(file[38..165])
    author = ""
    map = parse_map(data: file[184..-1], type: "new")
    return nil if map.nil?
  when "attract"
    map_length = file[0..3].reverse.hd
    demo_length = file[4..7].reverse.hd
    map_data = file[8 .. 8 + map_length - 1]
    demo_data = file[8 + map_length .. 8 + map_length + demo_length - 1]

    level_id = map_data[0..3].reverse.hd
    title = parse_str(map_data[30..157])
    index = map_data[159..-1].split(//).find_index("\x00") + 158
    author = map_data[159..index]
    map = parse_map(data: map_data[index + 2..-1], type: "new")
    # demo = parse_demo(data: demo_data, attract: true) # no se si el attract hace falta, comparar esto con una replay normal
  when "old"
    title = file.split('#')[0][1..-1]
    author = "Metanet Software"
    map = parse_map(data: file.split("#")[1], type: "old")
    return nil if map.nil?
  else
    print("ERROR: Incorrect type (level, attract, old).")
    return 0
  end
  {title: title, author: author, tiles: map[:tiles], objects: map[:objects]}
end

# <---------------------------------------------------------------------------->
#                                SAVING MAPS
# <---------------------------------------------------------------------------->

# locked door and trap door switches are not counted in N++!
def generate_map(tiles: [], objects: [], type: "new")
  case type
  when "new"
    tile_data = tiles.flatten.map{ |b| [b.to_s(16).rjust(2,"0")].pack('H*')[0] }.join
    object_counts = ""
    object_data = ""
    OBJECTS.sort_by{ |id, entity| id }.each{ |id, entity|
      if ![7,9].include?(id) # ignore door switches for counting
        object_counts << objects.select{ |o| o[0] == id }.size.to_s(16).rjust(4,"0").scan(/../).reverse.map{ |b| [b].pack('H*')[0] }.join
      else
        object_counts << "\x00\x00"
      end
      if ![6,7,8,9].include?(id) # doors must once again be treated differently
        object_data << objects.select{ |o| o[0] == id }.map{ |o| o.map{ |b| [b.to_s(16).rjust(2,"0")].pack('H*')[0] }.join }.join
      elsif [6,8].include?(id)
        doors = objects.select{ |o| o[0] == id }.map{ |o| o.map{ |b| [b.to_s(16).rjust(2,"0")].pack('H*')[0] }.join }
        switches = objects.select{ |o| o[0] == id + 1 }.map{ |o| o.map{ |b| [b.to_s(16).rjust(2,"0")].pack('H*')[0] }.join }
        object_data << doors.zip(switches).flatten.join
      end
    }
    map_data = tile_data + object_counts.ljust(80, "\x00") + object_data
  when "old"
    header = "00000000"
    tile_data = tiles.flatten.map{ |t| t.to_s(16).rjust(2,"0").reverse }.join
    objs = objects.reject{ |o| !OBJECTS.key?(o[0]) }.map{ |o| o.dup }
    doors_exit = objs.select{ |o| o[0] == 3 }.zip(objs.select{ |o| o[0] == 4 }).map{ |p| [3, p[0][1], p[0][2], p[1][1], p[1][2]] }
    doors_lock = objs.select{ |o| o[0] == 6 }.zip(objs.select{ |o| o[0] == 7 }).map{ |p| [6, p[0][1], p[0][2], p[0][3], p[1][1], p[1][2]] }
    doors_trap = objs.select{ |o| o[0] == 8 }.zip(objs.select{ |o| o[0] == 9 }).map{ |p| [8, p[0][1], p[0][2], p[0][3], p[1][1], p[1][2]] }
    objs = objs.select{ |o| ![3,4,6,7,8,9].include?(o[0]) }.+(doors_exit).+(doors_lock).+(doors_trap).stable_sort_by{ |o| o[0] }
    entities = (0..25).to_a.map{ |id| [id, []] }.to_h
    objs.each{ |o|
      next if !entities.key?(OBJECTS[o[0]][:old])
      s = o[1..OBJECTS[o[0]][:att]].map{ |a| a.to_s(16).rjust(2, "0").reverse }.join
      entities[OBJECTS[o[0]][:old]].push(s)
    }
    object_data = entities.map{ |k, v| v.size.to_s(16).rjust(4, "0").scan(/../m).map(&:reverse).join + v.join }.join
    footer = "00000000"
    map_data = header + tile_data + object_data + footer
  else
    print("ERROR: Incorrect type (new, old).")
    return 0
  end
  map_data
end

def generate_file(tiles: [], objects: [], demo: [], mode: "solo", title: "Autogen", folder: "", type: "level")
  data = ""
  if folder[-1] != "/" && !folder.empty? then folder = folder + "/" end
  case type
  when "level"
    data = ("\x00" * 4).force_encoding("ascii-8bit") # magic number ?
    data << (1230 + 5 * objects.size).to_s(16).rjust(8,"0").scan(/../).reverse.map{ |b| [b].pack('H*')[0] }.join.force_encoding("ascii-8bit") # filesize
    data << ("\xFF" * 4).force_encoding("ascii-8bit") # static data
    data << (mode == "unset" ? "\x04" : (mode == "race" ? "\x02" : (mode == "coop" ? "\x01" : "\x00"))).force_encoding("ascii-8bit")
    data << ("\x00" * 3 + "\x25" + "\x00" * 3 + "\xFF" * 4 + "\x00" * 14).force_encoding("ascii-8bit") # static data
    data << title[0..126].ljust(128,"\x00").force_encoding("ascii-8bit") # map title
    data << ("\x00" * 18).force_encoding("ascii-8bit") # static data
    data << generate_map(tiles: tiles, objects: objects, type: "new").force_encoding("ascii-8bit") # map data
  when "attract"

  when "old"
    data << "$#{title}#"
    data << generate_map(tiles: tiles, objects: objects, type: "old")
    data << "#"
  else
    print("ERROR: Incorrect type (level, attract, old).")
    return 0
  end
  data
end

# <---------------------------------------------------------------------------->
#                              ACTUAL SCRIPT
# <---------------------------------------------------------------------------->

folder = Dir.pwd + "/" + FOLDER
empty = 1
maps = Dir.entries(folder)
           .select{ |f| File.file?(folder + "/" + f) }
           .sort_by{ |f|
             if SORT
               row = f[/([a-z]+)-(\d+)-(\d+)/i, 1].to_s
               col = f[/([a-z]+)-(\d+)-(\d+)/i, 2].to_i
               lvl = f[/([a-z]+)-(\d+)-(\d+)/i, 3].to_i
               [col, row, lvl]
             else
               f
             end
           }
           .map{ |f| parse_file(filename: folder + "/" + f, type: "level") }
           .compact
           .map{ |map|
             name = map[:title].to_s
             if name.length <= PREFIX
               if !SHORT
                 name = "empty_#{empty}"
                 empty += 1
               end
             else
               name = name[PREFIX..-1]
             end 
             generate_file(tiles: map[:tiles], objects: map[:objects], title: name, type: "old")
           }
           .join("\n")
File.binwrite(TAB + ".txt", maps)
