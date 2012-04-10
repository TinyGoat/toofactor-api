# Sinatra is for closers
#
require 'sinatra'
  set :sessions, true
  set :logging, true
  set :dump_errors, true
  set :static, true
  set :public_folder, 'public'

require 'sinatra/cookies'
require 'json'
require 'builder'

# Ruby dudes are all about class baby
# 
class TooFactor < Sinatra::Application

  # Everything is a hash
  # 
  require "redis"
  $redis = Redis.new 
  
  # Ho, ho, ho
  #
  require 'haml'

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

  # Move along son
  #
  get '/' do
    haml :root
  end

  # Route me harder
  #
  get %r{/api/([\w]+)/([\w]+)} do |match,type|
    confirm = "#{match}"
    if ($redis.exists confirm)
      tstamp = Time.now.to_i
      cookies[:TooFactor] = match,tstamp
      cmatch = customer_match("#{match}")
      if (type == "json")
        content_type :json
        { :auth => cmatch, :timestamp => tstamp }.to_json
      elsif (type == "xml")
        xml = Builder::XmlMarkup.new
        xml.token { |b| b.auth(cmatch); b.timestamp(tstamp) }
      end
    else
      haml :nomatch
    end
  end

end
