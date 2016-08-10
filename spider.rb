require './osm.rb'
require 'set'
require 'json'
require 'optparse'

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: example.rb [options]"

  opts.on("-v", "--verbose", "Run verbosely") do
    options[:verbose] = true
  end

  opts.on("-uSTRING", "--user-agent=STRING",
          "Set the user agent to STRING") do |user_agent|
    options[:user_agent] = user_agent
  end

  opts.on("-oURL", "--overpass-url=URL",
          "Use Overpass server at URL (including /interpreter)") do |url|
    options[:overpass_url] = url
  end

  opts.on("-h", "--help", "Display this help text") do
    puts opts
    exit
  end
end.parse!

$osm = OSM.new(options)

def is_interesting?(r)
  (r['public_transport'] == 'stop_area') ||
    (r['public_transport'] == 'stop_area_group') ||
    (r['type'] == 'stop_area') ||
    (r['type'] == 'stop_area_group') ||
    (r['type'] == 'site')
end

def interesting_parent_relations(obj)
  obj.used_by(:relation).select {|r| is_interesting?(r)}
end

def interesting_child_relations(obj)
  obj.members(:relation).select {|r| is_interesting?(r)}
end

def explore(fn, root)
  seen = root.to_set
  front = seen
  #puts front.map{|x| x.to_s}.join(", ")
  loop do
    front = front.
            collect_concat {|x| fn.call(x)}.
            select {|obj| not seen.include? obj}.
            to_set
    #puts front.map{|x| x.to_s}.join(", ")
    break if front.empty?
    seen += front
  end
  return seen
end

def find_transit_routes(station_obj)
  relations = explore(method(:interesting_parent_relations), [station_obj])

  relations = explore(method(:interesting_child_relations), relations)

  nodes = Set.new
  nodes.add(station_obj)

  relations.each do |r|
    new_nodes = r.nodes.select do |n|
      (['station', 'stop', 'tram_stop'].include? n['railway'] ) ||
        (['stop', 'stop_position', 'tram_stop'].include? n['public_transport'])
    end

    new_nodes.each do |n|
      nodes.add(n) unless nodes.include?(n)
    end
  end

  ways = Set.new
  nodes.each do |n|
    new_ways = n.used_by(:way).select do |w|
      ['subway', 'light_rail', 'tram', 'rail'].include? w['railway']
    end

    new_ways.each do |w|
      ways.add(w) unless ways.include?(w)
    end
  end.to_set

  any_item = nodes + ways + relations
  routes = any_item.collect_concat do |o|
    o.used_by(:relation).select do |r|
      ['subway', 'light_rail', 'tram', 'train', 'railway'].include? r['route']
    end
  end.to_set

  return routes
end

$COLORS={
  :station  => ['#333333', '#f0f0f0'],
  :node     => ['#00e673', '#e5fff2'],
  :way      => ['#0088cc', '#e5f6ff'],
  :relation => ['#9933ff', '#f2e5ff']
}

def sanitize(str)
  return nil if str.nil?

  s = str.clone
  s.gsub!(/>/, "&gt;")
  s.gsub!(/</, "&lt;")
  s.gsub!(/&/, "&amp;")
  s.gsub!(/"/, "&quot;")
  s
end

def label_for(obj, root)
  dot_name = obj.to_s
  name = sanitize(obj['name'])
  tags = ['type', 'railway', 'public_transport', 'route']

  colors = (obj == root) ? $COLORS[:station] : $COLORS[obj.type]
  name = sanitize(name) unless name.nil?
  puts "#{dot_name} [shape=none,margin=0,label=<"
  puts "<TABLE STYLE=\"rounded\" COLOR=\"#{colors[0]}\" BGCOLOR=\"#{colors[1]}\" BORDER=\"1\" CELLBORDER=\"0\" CELLSPACING=\"0\" CELLPADDING=\"4\">"
  puts "<TR><TD><FONT POINT-SIZE=\"8\">#{obj.type} #{obj.id}</FONT></TD></TR>"
  puts "<TR><TD>#{name}</TD></TR>" unless name.nil?
  tags.each do |t|
    k = sanitize(t)
    if obj.tags.has_key?(t)
      v = sanitize(obj.tags[t])
      puts "<TR><TD><FONT FACE=\"courier\">#{k}=#{v}</FONT></TD></TR>"
    end
  end
  puts "</TABLE>>];"
end

def dot_output(r, root)
  label_for(r, root)
  if r.included_via.nil?
    []
  else
    puts "#{r} -> #{r.included_via}"
    [r.included_via]
  end
end

def calculate_station_score(station_obj)
  routes = find_transit_routes(station_obj)

  counts = Hash[routes.group_by {|r| r['route']}.map {|rt, l| [rt, l.size]}]

  a = ((counts['train'] || 0)).to_i
  b = ((counts['subway'] || 0) + (counts['light_rail'] || 0)).to_i
  c = ((counts['railway'] || 0) + (counts['tram'] || 0)).to_i

  if a > 0 && b > 0
    a *= 2
    b *= 2
  end

  score = (100 * [a, 9].min +
           10 * [b, 9].min +
           [c, 9].min)

  return score
end

typ = ARGV[0].split(",")[0].to_sym
id = ARGV[0].split(",")[1].to_i
station_obj = $osm.get_root(typ, id, nil)
routes = find_transit_routes(station_obj)
puts "digraph {"
explore(lambda {|r| dot_output(r, station_obj)}, routes)
puts "}"

#bbox = "st_transform(st_setsrid(st_makebox2d(st_point(-0.2911376953125,51.6248374617432), st_point(0.087890625,51.42661449707482)), 4326),900913)"

# data = JSON.load(File.read(ARGV[0]))

# $stderr.puts "## starting with #{data['elements'].size} elements"

# data['elements'].each do |elt|
#   typ = elt['type'].to_sym
#   id = elt['id'].to_i

#   station_obj = $osm.get_root(typ, id, nil)
#   next if station_obj.nil?

#   railway = station_obj['railway']
#   aerialway = station_obj['aerialway']

#   next unless aerialway == 'station' || ['station', 'halt', 'tram_stop'].include?(railway)

#   score = calculate_station_score(station_obj)
#   name = station_obj['name']
#   $stdout.puts "#{score}\t#{station_obj}\t#{railway || aerialway}\t#{name.inspect}"
#   $stdout.flush
# end
