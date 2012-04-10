# Sinatra is for closers
#
require 'sinatra'
  set :sessions, true
  set :logging, true
  set :dump_errors, true
  set :static, true
  set :public_folder, 'public'

require 'sinatra/cookies'

# Gemmy, gem, gem
#
require 'json'
require 'builder'

# Ho, ho, ho
#
require 'haml'

# Ruby dudes are all about class baby
# 
class TooFactor < Sinatra::Application
  
  # Everything is a hash
  # 
  require "redis"
  $redis = Redis.new 
  
  # Token routines
  #
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
      if ($redis.exists confirm)
        tstamp = Time.now.to_i
        cookies[:TooFactor] = match,tstamp
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
      if ($redis.exists confirm)
        tstamp = Time.now.to_i
        cookies[:TooFactor] = match,tstamp
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

end
