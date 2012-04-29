# Sinatra is for closers
#
require 'sinatra'
  set :root, File.dirname(__FILE__)
  set :sessions, false
  set :static, false
  set :static_cache_control, [:private, :max_age => 60]
  set :public_folder, 'public'
  set :environment, :development
  set :server, %w[unicorn thin mongrel webrick]

require 'sinatra/cookies'
require 'sinatra/multi_route'
require 'sinatra/json'

require 'builder'
require 'haml'
require 'digest/sha1'
require 'twilio-ruby'
require 'redis'
require 'redis-namespace'
require 'pony'

configure :production do

  set :dump_errors, false
  set :raise_errors, false
  set :logging, true

  # Redis
  #
  ENV["REDISTOGO_URL"] = 'redis://redistogo:809165c597aee3f873f3a0776ba03cac@gar.redistogo.com:9163'
  uri = URI.parse(ENV["REDISTOGO_URL"])
  $redis_customer = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  $redis_token    = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  $redis_log      = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

  # Headers and caching
  #
  sha1, date = `git log HEAD~1..HEAD --pretty=format:%h^%ci`.strip.split('^')

  before do
    cache_control :public, :must_revalidate, :max_age=>0
    etag sha1
    last_modified date
  end
end

configure :development do

  $redis_customer = Redis.new(:host => "127.0.0.1", :port => 6379)
  $redis_token    = Redis.new(:host => "127.0.0.1", :port => 6379)
  $redis_log      = Redis.new(:host => "127.0.0.1", :port => 6379)

  set :dump_errors, true
  set :raise_errors, true
  set :logging, true
  set :show_exceptions, true

end

# Find Godot
#
not_found do
  status 404
end

error do
  'Sorry there was a nasty error - ' + env['sinatra.error'].name
end

$base_url = "http://dev.toofactor.com/"
$default_expire = 90

# Geoff likes logs
#
def log_to_redis(message)
  $redis_log.publish("LOG", message)
end

# Seed baseline test
#
$redis_customer.set("1000", "0")

def customer?(confirm)
  if ($redis_customer.exists(confirm))
    true if ($redis_customer.get(confirm) == "0") rescue false
  end
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

def email_token(client_email, token, expires)
  email_body = "Your authentication token is: " + token
  Pony.mail({
    :to => client_email,
    :subject => "Your authentication token",
    :body => email_body,
    :via => :smtp,
    :via_options => {
      :address              => 'smtp.gmail.com',
      :port                 => '587',
      :enable_starttls_auto => true,
      :user_name            => 'token@toofactor.com',
      :password             => '75707acd0d74075ade87fb925b2e0f76',
      :authentication       => :plain, 
      :domain               => "toofactor.com"
    }
  })
end

# Send token to client phone
#
def send_sms(cmatch, tstamp, number)
  #if (valid_number?(number))
    account_sid = 'AC7cf1d4ccfee943d89892eadd0dbb255e'
    auth_token = 'e32e80fd3d2bea9fe0133a410866189d'
    response = begin
      @client = Twilio::REST::Client.new account_sid, auth_token
      sms_token_status = @client.account.sms.messages.create(
        :from => '+14155992671',
        :to => number,
        :body => cmatch
        ).status
      record_sms_token(cmatch, tstamp)
      status 200
      sms_token_status
    rescue
      status 500
      'Twilio Error'
    end
  #end
  case request.preferred_type
    when 'application/json'
      json :response => response
    when 'application/xml'
      builder do |xml|
        xml.response(response)
      end
    else
      response.to_s
  end
end

# Create unique, expirable client URL's
#
def create_client_hash(cmatch, tstamp)
  gohash = cmatch + tstamp.to_s
  client_sha = Digest::RMD160.new << gohash
  client_url = $base_url + "client/" + client_sha.to_s
  record_client_token(client_sha, cmatch)
  return client_url
end

def create_token_url(cmatch)
  token_url = $base_url + "token/" + cmatch
end


# Token options: JSON and XML
#
def json_token(cmatch, tstamp)
  client_url    = create_client_hash(cmatch, tstamp)
  token_url     = create_token_url(cmatch)
  token_expires = tstamp + 90
  json :auth => cmatch, :timestamp => tstamp, :expires => token_expires, :token_url => token_url, :client_url => client_url
end

def xml_token(cmatch, tstamp)
  @client_url     = create_client_hash(cmatch, tstamp)
  @cmatch         = cmatch
  @timestamp      = tstamp
  @token_url      = create_token_url(cmatch)
  @token_expires  = tstamp + 90
  builder :token
end

# Output token, default to JSON
#
def output_token(match, type, number=0)
  
  tstamp = Time.now.to_i
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
get '/token/*', '/client/*' do |purl|
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

# Paranoia will destroy ya
#
patch '*' do
  status 418
end

post '*' do
  status 418
end
