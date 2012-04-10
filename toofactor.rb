# Sinatra is for closers
#
require 'sinatra'
  set :sessions, true
  set :logging, true
  set :dump_errors, true
  set :static, true
  set :public_folder, 'public/'

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

# Route me harder
#
get %r{/api/([\w]+)} do |match|
  tokenize(0, 7, "#{match}")
end
