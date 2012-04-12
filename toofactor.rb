# Sinatra is for closers
#
require 'sinatra'
  set :sessions, true
  set :logging, true
  set :dump_errors, true
  set :static, true
  set :static_cache_control, [:private, :max_age => 60]
  set :public_folder, 'public'

require 'sinatra/cookies'

require 'json'
require 'builder'
require 'haml'
require 'digest/sha1'

configure :production do

  sha1, date = `git log HEAD~1..HEAD --pretty=format:%h^%ci`.strip.split('^')
  
  require 'rack/cache'
  use Rack::Cache

  before do
    cache_control :public, :must_revalidate, :max_age=>300
    etag sha1
    last_modified date
  end

  # Find Godot
  #
  not_found do
    haml :notfound
  end
  
  error do
    'Sorry there was a nasty error - ' + env['sinatra.error'].name
  end

end

# Ruby dudes are all about class baby
# 
class TooFactor < Sinatra::Application
 
  $base_url = "http://toofactor.com/client/"
  redis_host = "127.0.0.1"

  # Everything is a hash
  # 
  require "redis"
  $redis = Redis.new(:host => redis_host, :port => 6379) 

  def customer?(confirm)
    $redis.exists confirm
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

  def record_client_token(client_sha, token)
    $redis.set(client_sha, token)
    $redis.expire(client_sha, 90)
  end

  def customer_match(match)
    customer = $redis.get match
    return tokenize(0, 7, customer)
  end

  def create_client_hash(cmatch)
    client_sha = Digest::SHA2.new << cmatch
    client_url = $base_url + client_sha.to_s
    record_client_token(client_sha, cmatch)
    return client_url
  end

  def json_token(cmatch, tstamp)
    client_url = create_client_hash(cmatch)
    content_type :json
    { :auth => cmatch, :timestamp => tstamp, :client_url => client_url }.to_json
  end

  def xml_token(cmatch, tstamp)
    client_url = create_client_hash(cmatch)
    xml = Builder::XmlMarkup.new
    xml.token { |b| b.auth(cmatch); b.timestamp(tstamp); b.client_url(client_url) }
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
    # begin 
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
    # rescue
    #  haml :eek
   # end
  end

  # Client access
  #
  get %r{/client/([\w]+)/$} do |match|
    client = "#{match}"
    if (client_token_exist?(client))
      client_token(client)
    else
      haml :client_expired
    end
  end
    
end

