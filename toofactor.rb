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
require 'twilio-ruby'

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
    $redis.exists(confirm)
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

  def tokenize_customer(match)
    customer = $redis.get(match)
    return tokenize(0, 7, customer)
  end

  # Twilio functions
  #
  def valid_number?(number)
    true if Float(number) rescue false
  end
  
  def send_sms(cmatch, tstamp, number)
    if (valid_number?(number))
      account_sid = 'AC7cf1d4ccfee943d89892eadd0dbb255e'
      auth_token = 'e32e80fd3d2bea9fe0133a410866189d'
      @client = Twilio::REST::Client.new account_sid, auth_token
      sms_token_status = @client.account.sms.messages.create(
        :from => '+14155992671',
        :to => number,
        :body => cmatch
        ).status
      else
        haml :sms_send_error
      end
  end

  def create_client_hash(cmatch, tstamp)
    gohash = cmatch + tstamp.to_s
    client_sha = Digest::RMD160.new << gohash
    client_url = $base_url + client_sha.to_s
    record_client_token(client_sha, cmatch)
    return client_url
  end

  def json_token(cmatch, tstamp)
    client_url = create_client_hash(cmatch, tstamp)
    content_type :json
    { :auth => cmatch, :timestamp => tstamp, :client_url => client_url }.to_json
  end

  def xml_token(cmatch, tstamp)
    client_url = create_client_hash(cmatch, tstamp)
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
        cmatch = tokenize_customer("#{match}")
        json_token(cmatch, tstamp)
      else
        haml :nomatch
      end
    rescue
      haml :eek
    end
  end

  get %r{/api/([\w]+)/([\w]+)/([\w]+)} do |match,type,number|
    confirm = "#{match}"
    confirm.freeze
#    begin 
      if (customer?(confirm))
        tstamp = Time.now.to_f
        cookies[:TooFactor] = tstamp
        cmatch = tokenize_customer("#{match}")
        case type
          when "sms"
            send_sms(cmatch, tstamp, number)
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
 #   rescue
 #     haml :eek
 #   end
  end

end

