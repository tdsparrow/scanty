require 'rubygems'
require 'appengine-rack'
require 'sinatra'

AppEngine::Rack.configure_app(
    :application => "tdtitle",
    :precompilation_enabled => true,
    :version => "1")

require 'main'

use ::Rack::Reloader
run Sinatra::Application
