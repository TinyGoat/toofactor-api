# Sinatra is for closers
#
require 'sinatra'
  set :sessions, false
  set :logging, false
  set :dump_errors, false
  set :raise_errors, false
  set :static, true
  set :static_cache_control, [:private, :max_age => 60]
  set :public_folder, 'public'

require 'sinatra/cookies'

require 'json'
require 'builder'
require 'haml'
require 'digest/sha1'
require 'twilio-ruby'
require 'redis'
require 'redis-namespace'

# Find Godot
#
not_found do
  status 404
end

error do
  'Sorry there was a nasty error - ' + env['sinatra.error'].name
end

$base_url = "http://dev.toofactor.com/client/"
#ENV["REDISTOGO_URL"] = 'redis://redistogo:809165c597aee3f873f3a0776ba03cac@gar.redistogo.com:9163'
#uri = URI.parse(ENV["REDISTOGO_URL"])
redis_host = "127.0.0.1"
   

# It rubs the Redis on it's skin
# 

#$redis_customer = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)                                                             
#$redis_token    = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password) 
$redis_customer = Redis.new(:host => redis_host, :port => 6379)
$redis_token    = Redis.new(:host => redis_host, :port => 6379) 
$redis_log      = Redis.new(:host => redis_host, :port => 6379)

# Geoff likes logs
#
def log_to_redis(message)
  $redis_log.publish("LOG", message)
end

# Seed baseline test
#
$redis_customer.set("1000", "foo")

# Customer functions
# 
def customer?(confirm)
  $redis_customer.exists(confirm)
end

def client_purl?(purl)
  $redis_token.exists(purl)
end
 
# Record tokens & URL's for verification
#
def record_client_token(client_sha, token)
  $redis_token.multi do
    $redis_token.set(client_sha, token)
    $redis_token.set(token, client_sha)
    $redis_token.expire(client_sha, 90)
    $redis_token.expire(token, 90)
  end
end

# Same for SMS
#
def record_sms_token(cmatch, tstamp)
  $redis_token.multi do
    $redis_token.set(cmatch, tstamp)
    $redis_token.expire(cmatch, 90)
  end
end

# Generate random Hex
#
def gen_hex
  prng = Random.new
  prng.rand(0..15).to_s(base=16)
end

# Potentially set token length per customer
#
def tokenize(min, max, token)
  token = ""
  (min..max).each do 
    token = token + gen_hex
  end
  return token
end

def tokenize_customer(match)
  customer = $redis_customer.get(match) 
  return tokenize(0, 7, customer)
end


# SMS functions
#
#def valid_number?(number)
#  true if Float(number) rescue false
#end


# Send token to client phone
#
def send_sms(cmatch, tstamp, number)
  #if (valid_number?(number))
    account_sid = 'AC7cf1d4ccfee943d89892eadd0dbb255e'
    auth_token = 'e32e80fd3d2bea9fe0133a410866189d'
    begin
      @client = Twilio::REST::Client.new account_sid, auth_token
      sms_token_status = @client.account.sms.messages.create(
        :from => '+14155992671',
        :to => number,
        :body => cmatch
        ).status
        record_sms_token(cmatch, tstamp)
    rescue
      'Twilio Error'
    end
  #end
end

# Create unique, expirable client URL's
#
def create_client_hash(cmatch, tstamp)
  gohash = cmatch + tstamp.to_s
  client_sha = Digest::RMD160.new << gohash
  client_url = $base_url + client_sha.to_s
  record_client_token(client_sha, cmatch)
  return client_url
end

# Token options: JSON and XML
#
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

# Output token, default to JSON
#
def output_token(match, type, number)
  
  match   ||= "ERROR" 
  type    ||= "json"
  number  ||= 0
  
  tstamp = Time.now.to_f
  cmatch = tokenize_customer("#{match}")
  message = match + ":" + type + ":" + number
  log_to_redis(message)    
  
  # Offer various output formats
  #
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
end 
 
# Determine if a client URL/token is valid
#
get '/client/*' do |purl|
  if (client_purl?(purl))
    status 202
  else
    status 410
  end
end

# Confirm token is valid
#
get '/token/*' do |purl|
  if (client_purl?(purl))
    status 202
  else
    status 410
  end
end

# Produce token via API call
#
get '/api/*/*/*' do |*args|
  match, type, number = args
    if (customer?(match))
      output_token(match, type, number)
    else
      status 401
    end
end


