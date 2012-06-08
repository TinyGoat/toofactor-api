# Sinatra is for closers
#
require 'sinatra'
  set :root, File.dirname(__FILE__)
  set :sessions, false
  set :static, false
  set :static_cache_control, [:private, :max_age => 0]
  set :public_folder, 'public'
  set :environment, :development
  set :server, %w[unicorn]

require 'sinatra/multi_route'
require 'sinatra/json'
require 'builder'
require 'digest/sha1'
require 'twilio-ruby'
require 'redis'
require 'redis-namespace'
require 'crypt-isaac'
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

  not_found do
    redirect 'http://www.toofactor.com', 302
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
  $redis_log = Redis.new(:host => "127.0.0.1", :port => 6379)

  error do
    'Sorry there was a nasty error - ' + env['sinatra.error'].name
  end

end

$base_url = "http://api.toofactor.com/"
$default_expire = 90

# Geoff likes logs
#
def log_to_redis(message)
  $redis_log.publish("LOG", message)
end

def customer?(confirm)
  $redis_customer.get(confirm) == "0"
end

def dev_customer?(confirm)
  $redis_dev.get(confirm)
end

def client_purl?(purl)
  $redis_token.exists(purl)
end

# Record tokens & URL's for verification
#
def record_token(token, tstamp, expiration=90)
  $redis_token.multi do
    $redis_token.set(token, tstamp)
    $redis_token.expire(token, expiration)
  end
end

# Generate random Hex
#
def gen_hex
  # prng = Random.new
  prng = Crypt::ISAAC.new
  prng.rand(15).to_s(base=16)
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
  return tokenize(0, 5, match)
end

# SMS functions
#
def email_token(client_email, token, tstamp, expiration)

  output = "This token will expire in 5 minutes."
  email_body = "Your authentication token is: #{token.to_s}\n\n#{output}\n\n"
  token_url = create_token_url(token, tstamp)

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
    json :token => token, :token_url => token_url, :email_address => client_email, :token_generated => tstamp, :token_expires => tstamp + expiration, :status => 'Email sent'
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
      record_token(cmatch, tstamp, expiration)
      status 200
      token_url = create_token_url(cmatch, tstamp)
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
      token_url = "error" if token_url.nil?
      json :sms_status => response.to_s, :token => cmatch, :token_url => token_url, :phone_number => number, :token_generated => tstamp, :token_expires => tstamp + expiration 
  end
end

# Create unique, expirable client URL's
#
def create_token_url(cmatch, tstamp)
  token_url = $base_url + "token/" + cmatch
  record_token(cmatch, tstamp)
  return token_url
end

# Token options: JSON and XML
#
def json_token(cmatch, tstamp, expiration)
  token_url     = create_token_url(cmatch, tstamp)
  token_expires = tstamp + expiration
  json :auth => cmatch, :timestamp => tstamp, :expires => token_expires, :token_url => token_url
end

def xml_token(cmatch, tstamp, expiration)
  @cmatch         = cmatch
  @timestamp      = tstamp
  @token_url      = create_token_url(cmatch, tstamp)
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
get '/token/*/?', '/client/*/?' do |purl|
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
  
  if (dev_customer?(match))
    number = dev_customer?(match)
    output_token(match, type, number)
  elsif (customer?(match))
    number = "0" if number.empty?
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
