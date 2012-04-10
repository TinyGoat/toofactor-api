# Sinatra is for closers
#
require 'sinatra'
  set :sessions, true
  set :logging, true
  set :dump_errors, true
  set :static, true
  set :public_folder, 'public'

# Ruby dudes are allow about class baby
# 
class TooFactor < Sinatra::Application

  # Everything is a hash
  # 
  require "redis"

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
      token = token + gen_hex + " "
    end
    return token
  end

  def customer_match(match)
    redis = Redis.new
    if (redis.exists match)
      customer = redis.get match
      return tokenize(0, 7, customer)
    else
      haml :nomatch
    end
  end

  # Move along son
  #
  get '/' do
    "Nobody puts baby in the corner!"
  end

  # Route me harder
  #
  get %r{/api/([\w]+)} do |match|
    customer_match("#{match}")
  end

end
