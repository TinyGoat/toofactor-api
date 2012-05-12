# Sinatra is for closers
#
require 'sinatra'
  set :root, File.dirname(__FILE__)
  set :sessions, false
  set :static, false
  set :static_cache_control, [:private, :max_age => 0]
  set :public_folder, 'public'
  set :environment, :production
  set :server, %w[unicorn]

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
  $redis = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
    $redis_customer   = Redis::Namespace.new(:customer, :redis => $redis)
    $redis_token      = Redis::Namespace.new(:token, :redis => $redis)
    $redis_dev        = Redis::Namespace.new(:dev, :redis => $redis)
  $redis_log      = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)

  before do
    cache_control :nocache
  end

end

configure :development do

  set :dump_errors, true
  set :raise_errors, true
  set :logging, true
  set :show_exceptions, true

  $redis = Redis.new(:host => "127.0.0.1", :port => 6379)
    $redis_customer   = Redis::Namespace.new(:customer, :redis => $redis)
    $redis_token      = Redis::Namespace.new(:token, :redis => $redis)
    $redis_dev        = Redis::Namespace.new(:dev, :redis => $redis)
  $redis_log      = Redis.new(:host => "127.0.0.1", :port => 6379)

end

# Find Godot
#
not_found do
  erb :index
end

error do
  'Sorry there was a nasty error - ' + env['sinatra.error'].name
end

$base_url = "http://api.toofactor.com/"
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
def record_sms_token(cmatch, tstamp, expiration)
  $redis_token.multi do
    $redis_token.set(cmatch, tstamp)
    $redis_token.expire(cmatch, expiration)
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
  return tokenize(0, 5, customer)
end

# SMS functions
#
#def valid_number?(number)
#  true if Float(number) rescue false
#end

def email_token(client_email, token, tstamp, expiration)

  output = "This token will expire in 5 minutes."
  email_body = "Your authentication token is: #{token.to_s}\n\n#{output}\n\n"

  # Generate email thread to send token
  #
  email_outbound = Thread.new{
    ( Pony.mail(
      {
        :to => client_email,
        :subject => "Your authentication Token",
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
       }
      )
    )
  }
    # Fire that thread
    #
    email_outbound.join
    json :token => token, :email_address => client_email, :token_generated => tstamp, :token_expires => tstamp + expiration, :status => 'Email sent'
end

# Send token to client phone
#
def send_sms(cmatch, tstamp, number, expiration)
    account_sid = 'AC7cf1d4ccfee943d89892eadd0dbb255e'
    auth_token = 'e32e80fd3d2bea9fe0133a410866189d'
    response = begin
      @client = Twilio::REST::Client.new account_sid, auth_token
      sms_token_status = @client.account.sms.messages.create(
        :from => '+14155992671',
        :to => number,
        :body => cmatch
        ).status
      record_sms_token(cmatch, tstamp, expiration)
      status 200
      token_url = create_token_url(cmatch)
      sms_token_status
    rescue
      status 500
      'Twilio Error'
    end
  case request.preferred_type
    when 'application/json'
      json :response => response
    when 'application/xml'
      builder do |xml|
        xml.response(response)
      end
    else
      json :response => response.to_s, :token => cmatch, :url => token_url 
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
def json_token(cmatch, tstamp, expiration)
  client_url    = create_client_hash(cmatch, tstamp)
  token_url     = create_token_url(cmatch)
  token_expires = tstamp + expiration
  json :auth => cmatch, :timestamp => tstamp, :expires => token_expires, :token_url => token_url, :client_url => client_url
end

def xml_token(cmatch, tstamp, expiration)
  @client_url     = create_client_hash(cmatch, tstamp)
  @cmatch         = cmatch
  @timestamp      = tstamp
  @token_url      = create_token_url(cmatch)
  @token_expires  = tstamp + expiration
  builder :token
end

# Output token, default to JSON
#
def output_token(match, type, number)
  tstamp = Time.now.to_i
  cmatch = tokenize_customer("#{match}")
  message = match + ":" + number + ":" + type
  log_to_redis(message)

  # Offer various output formats
  #
  case type
    when "sms"
      send_sms(cmatch, tstamp, number, 90)
    when "json"
      json_token(cmatch, tstamp, 90)
    when "xml"
      xml_token(cmatch, tstamp, 90)
    when "email"
      email_token(number, cmatch, tstamp, 300)
    else
      json_token(cmatch, tstamp, 90)
  end
end

# Indexy
#
get '/' do
  erb :index
end

# Determine if a client URL/token is valid
#
get '/token/*', '/client/*' do |purl|
  if (client_purl?(purl))
    halt 202, erb(:valid)
  else
    halt 410, erb(:expired)
  end
end

# Produce token via API call
#
get '/api/*/*/*' do |*args|
  match, type, number = args
  if (customer?(match))
    output_token(match, type, number)
  else
    halt 401, erb(:invalid_api)
  end
end

# Paranoia will destroy ya
#
patch '*' do
  halt 418, erb(:teapot)
end

post '*' do
  halt 418, erb(:teapot)
end
