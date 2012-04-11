# Sinatra is for closers
#
require 'sinatra'
  set :sessions, true
  set :logging, true
  set :dump_errors, true
  set :static, true
  set :static_cache_control, [:private, :max_age => 60]
  set :public_folder, 'public'

require 'json'
require 'builder'
require 'haml'
require 'sinatra/cookies'

configure :production do

  sha1, date = `git log HEAD~1..HEAD --pretty=format:%h^%ci`.strip.split('^')
  
  require 'rack/cache'
  use Rack::Cache

  before do
    cache_control :public, :must_revalidate, :max_age=>300
    etag sha1
    last_modified date
  end
end

# Ruby dudes are all about class baby
# 
class TooFactor < Sinatra::Application
 
  redis_host = "127.0.0.1"

  # Everything is a hash
  # 
  require "redis"
  $redis = Redis.new(:host => redis_host, :port => 6379) 

  def customer?(confirm)
    $redis.exists confirm
  end

  def log_api(customer)
    $redis.incr customer
  end

  def gen_hex
    prng = Random.new
    prng.rand(0..15).to_s(base=16)
  end

  # Abstract so we can potentially set
  # token length per customer
  #
  def tokenize(min, max, token)
    token = ""
    (min..max).each do 
    token = token + gen_hex
    end
    return token
  end

  def customer_match(match)
    customer = $redis.get match
    log_api(match)
    return tokenize(0, 7, customer)
  end

  def json_token(cmatch, tstamp)
    content_type :json
    { :auth => cmatch, :timestamp => tstamp }.to_json
  end

  def xml_token(cmatch, tstamp)
    xml = Builder::XmlMarkup.new
    xml.token { |b| b.auth(cmatch); b.timestamp(tstamp) }
  end

  # Move along son
  #
  get '/' do
    haml :root
  end

  # Route me harder
  #
  get %r{/api/([\w]+)/$} do |match|
    confirm = "#{match}"
    confirm.freeze
    begin
      if (customer?(confirm))
        tstamp = Time.now.to_f
        cookies[:TooFactor] = tstamp
        cmatch = customer_match("#{match}")
        json_token(cmatch, tstamp)
      else
        haml :nomatch
      end
    rescue
      haml :eek
    end
  end

  get %r{/api/([\w]+)/([\w]+)} do |match,type|
    confirm = "#{match}"
    confirm.freeze
    begin 
      if (customer?(confirm))
        tstamp = Time.now.to_f
        cookies[:TooFactor] = tstamp
        cmatch = customer_match("#{match}")
        case type
          when "json"
            json_token(cmatch, tstamp)
          when "xml"
            xml_token(cmatch, tstamp)
          else
            json_token(cmatch, tstamp)
        end    
      else
        haml :nomatch
      end
    rescue
      haml :eek
    end
  end

  # Finding Godot
  #
  not_found do
      haml :notfound
  end

  error do
      'Sorry there was a nasty error - ' + env['sinatra.error'].name
  end
end

