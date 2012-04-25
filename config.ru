require './toofactor'
require 'rubygems'
require 'bundler/setup'
use Rack::ShowExceptions
Bundler.require
run Sinatra::Application
