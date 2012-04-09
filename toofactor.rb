
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
  (min..max).each do 
    token = token + gen_hex + " "
  end
  return token
end

# It rubs the lotion on it's skin
#
puts tokenize(0, 7, "")
