require 'redis'
require 'uri'
require 'activerecord'

# Redis
#
ENV["REDISTOGO_URL"] = 'redis://redistogo:809165c597aee3f873f3a0776ba03cac@gar.redistogo.com:9163'
uri = URI.parse(ENV["REDISTOGO_URL"])

begin
  @redis_log = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  @redis_log.inspect
rescue
  p "Cannot access Redis instance.."
  sleep 10
  retry
end

class Customer < ActiveRecord::Base
end

ActiveRecord::Base.establish_connection(
  :adapter => 'sqlite3',
  :dbfile =>  'example.sqlite3.db'
)

# Dev
# @redis_log  = Redis.new(:host => "127.0.0.1", :port => 6379, :timeout => 0)     

# Loop
#
begin
  @redis_log.subscribe('LOG') do |on|
    on.message do |channel, data|
      customer_api, client_address, type = data.split(":")
      puts "#{customer_api} - #{client_address} #{type}"
    end
  end
rescue
  p "Error accessing Redis channel .. retrying"
  sleep 2
  retry
end
