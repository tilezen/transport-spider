require 'rubygems'
require 'open-uri/cached'
require 'rexml/document'
require 'uri'

DEFAULT_USER_AGENT = "transport-spider.rb (contact zere)"
DEFAULT_OVERPASS_URL = "http://overpass.osm.rambler.ru/cgi/interpreter"

class OSM
  attr_reader :verbose

  def initialize(options = {})
    @verbose = options[:verbose] || false
    @user_agent = options[:user_agent] || DEFAULT_USER_AGENT
    @overpass_url = options[:overpass_url] || DEFAULT_OVERPASS_URL

    # global cache of objects to avoid re-fetching multiple times.
    # ([type, id] => xml node)
    @element_cache = Hash.new
    # ([type, id] => Hash(used_by_type => [id]))
    @usedby_cache = Hash.new

    @request_counter = 0
    @next_counter = 0
  end

  def get_root(type, id, included_via=nil)
    return OSMObject.new(type, id, self, included_via)
  end

  def api_get_element(type, id)
    doc = @element_cache[[type, id]]

    if doc.nil?
      doc = overpass_request("#{type}(#{id});out;")
      elt = doc.get_elements("//#{type}")[0]
      @element_cache[[type, id]] = elt.deep_clone
    end

    return doc
  end

  def api_get_used_by(type, id)
    data = @usedby_cache[[type, id]]

    if data.nil?
      ways = Set.new
      relations = Set.new

      if type == :node
        overpass_request("node(#{id});way(bn);out;").
          get_elements("//way").
          each do |w|
          wid = w.attributes['id'].to_i
          ways.add(wid)
          @element_cache[[:way, wid]] = w.deep_clone
        end
      end

      input_set = type.to_s[0]
      x = overpass_request("#{type}(#{id});rel(b#{input_set});out;")

      x.get_elements("//relation").
        each do |r|
        rid = r.attributes['id'].to_i
        relations.add(rid)
        @element_cache[[:relation, rid]] = r.deep_clone
      end

      data = {
        :way => ways,
        :relation => relations
      }
      @usedby_cache[[type, id]] = data
    end

    return data
  end

  def overpass_request(query)
    uri = URI.parse(@overpass_url)
    params = { :data => query }
    uri.query = URI.encode_www_form(params)
    xml = uri.open.read
    #$stderr.puts "OVERPASS: #{query.inspect}"
    #$stderr.puts xml
    @request_counter += 1
    if @request_counter > @next_counter
      @next_counter += 100
      $stderr.puts "# requests: #{@request_counter}"
    end
    REXML::Document.new xml
  end
end

class OSMObject
  attr_accessor :type, :id, :included_via

  def initialize(type, id, osm, included_via)
    @type, @id, @osm, @included_via = type, id, osm, included_via
    @cache, @used_by_cache = nil, nil
  end

  def tags
    ensure_cache

    t = Hash.new
    @cache.get_elements("//tag").each do |x|
      #puts x.inspect
      t[x.attributes['k']] = x.attributes['v']
    end
    return t
  end

  def [](key)
    tags[key]
  end

  def ==(other)
    @type == other.type && @id == other.id
  end

  def hash
    [@type, @id].hash
  end

  alias :eql? :==

  def to_s
    "#{@type.to_s[0]}#{@id}"
  end

  def nodes
    ensure_cache

    ns = Set.new

    if @type == :way
      @cache.get_elements("//nd").each do |nd|
        ns.add(nd.attributes['ref'].to_i)
      end

    elsif @type == :relation
      @cache.get_elements("//member").each do |m|
        if m.attributes['type'] == 'node'
          ns.add(m.attributes['ref'].to_i)
        end
      end
    end

    return ns.map {|id| @osm.get_root(:node, id, self)}
  end

  def members(type)
    ensure_cache

    ms = Set.new

    if @type == :relation
      @cache.get_elements("//member").each do |m|
        if m.attributes['type'] == type.to_s
          ms.add(m.attributes['ref'].to_i)
        end
      end
    end

    return ms.map {|id| @osm.get_root(type, id, self)}
  end

  def used_by(type)
    ensure_used_by

    return @used_by_cache[type].map {|id| @osm.get_root(type, id, self)}
  end

  private

  def ensure_cache
    return unless @cache.nil?

    doc = @osm.api_get_element(@type, @id)
    @cache = doc
  end

  def ensure_used_by
    return unless @used_by_cache.nil?

    @used_by_cache = @osm.api_get_used_by(@type, @id)
  end
end
