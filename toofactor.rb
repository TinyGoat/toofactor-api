# Sinatra is for closers
#
require 'sinatra'

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

# It rubs the lotion on it's skin
#
#uts tokenize(0, 7, "")

# Route me harder
#
get %r{/api/([\w]+)} do |match|
  tokenize(0, 7, "#{match}")
end
