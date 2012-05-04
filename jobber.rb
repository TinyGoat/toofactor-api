require 'redis'
require 'json'

$redis_log  = Redis.new(:host => "127.0.0.1", :port => 6379, :timeout => 0)     

# 
def push_to_sql
  
end

# Loop
#
$redis_log.subscribe('LOG') do |on|
  on.message do |channel, data|
    customer_api, client_address, type = data.split(":")
    puts "#{customer_api} - #{client_address} #{type}"
  end
end

