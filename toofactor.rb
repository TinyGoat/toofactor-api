# Sinatra is for closers
#
require 'sinatra'
  set :sessions, true
  set :logging, true
  set :dump_errors, true
  set :raise_errors, true
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

configure :production do
  
  set :dump_errors, false
  set :raise_errors, false
  
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
    haml :no_such_page
  end
  
  error do
    'Sorry there was a nasty error - ' + env['sinatra.error'].name
  end

end

configure :development do
  error do
    'Sorry there was a nasty error - ' + env['sinatra.error'].name
  end
end

# Ruby dudes are all about class baby
# 
class TooFactor < Sinatra::Application
 
  $base_url = "http://toofactor.com/client/"
  redis_host = "127.0.0.1"
  @salt = "2a108BNGCs8RrY0K9PQhU2T7fu10rCEQUeM3trw3a4cRgjIWe9c1185a5c5e9fc54612808977ee8f548b2258d31"    
  
  # It rubs the Redis on it's skin
  # 
  $redis = Redis.new(:host => redis_host, :port => 6379) 
    $redis_customer       = Redis::Namespace.new(:customer, :redis => $redis)
      $redis_client_url   = Redis::Namespace.new(:token, :redis => $redis_customer)
      $redis_customer_log = Redis::Namespace.new(:log, :redis => $redis_customer)
    $redis_site_stats     = Redis::Namespace.new(:stats, :redis => $redis)
  
  # Customer functions
  # 
  def customer?(confirm)
    $redis_customer.exists(confirm)
  end

  def client_purl?(purl)
    $redis_client_url.exists(purl)
  end

  def record_client_token(client_sha, token)
    $redis_client_url.multi do
      $redis_client_url.set(client_sha, token)
      $redis_client_url.expire(client_sha, 90)
    end
  end
  
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

  # Log the lot -- need to report on usage
  #
  def logit(*stuff)
    month = Time.now.month.to_s
    year = Time.now.year.to_s
    $redis_customer_log.multi do
    end
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
      begin
        @client = Twilio::REST::Client.new account_sid, auth_token
        sms_token_status = @client.account.sms.messages.create(
          :from => '+14155992671',
          :to => number,
          :body => cmatch
          ).status
      rescue
        haml :error_twilio
      end
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

  def output_token(match, type, number)
    
    type    ||= "json"
    number  ||= 0
    
    tstamp = Time.now.to_f
    cookies[:TooFactor] = tstamp
    cmatch = tokenize_customer("#{match}")
    
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
   
  # Create customer API key (salted hash of email address)
  # 
  def create_client_api(email)
    customer_api = Digest::RMD160.new << email + $salt
  end
     
### Go go Gadget TooFactor

  # Move along son
  #
  get '/' do
    haml :homepage
  end

  # Determine if a client URL is valid
  #
  get '/client/*' do |purl|
    if (client_purl?(purl))
      status 200
    else
      status 406
    end
  end

  ###### Nav sections
  #
  get '/signup/?' do
    'Hi'
  end

  get '/about/?' do
    'More about me'
  end

  get '/pricing/?' do
    'More pricing'
  end

  get '/login/?' do
    'Log me in'
  end

  ###### Process
  #
  # With no preference for format, we set to JSON
  #
  get %r{/api/([\w]+)/?$} do |match|      
    type    = "json"
    number  = 0
    begin 
       if (customer?(match))
         output_token(match, type, number)
       else
         @api_requested = match
         haml :no_api_match
       end
     rescue
       haml :fail_whale
    end
  end

  # Route me harder
  #
  get '/api/*/*/*' do |*args|
    match, type, number = args
    begin 
      if (customer?(match))
        output_token(match, type, number)
      else
        @api_requested = match
        haml :no_api_match
      end
    rescue
      haml :fail_whale
    end
  end

## End of line



end

