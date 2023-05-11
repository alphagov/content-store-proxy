
require 'sinatra/base'
require 'sinatra/multi_route'
require 'sinatra/custom_logger'
require 'logger'

require './lib/request_forwarder'
require './lib/response_comparator'

class ContentStoreProxyApp < Sinatra::Base
  register Sinatra::MultiRoute
  helpers Sinatra::CustomLogger

  configure :development, :production do
    logger = Logger.new(STDOUT)
    logger.level = Logger::DEBUG #if development?
    set :logger, logger
  end

  
  def initialize( primary_upstream: nil, secondary_upstream: nil)
    @primary = primary_upstream || ENV["PRIMARY_UPSTREAM"]
    @secondary = secondary_upstream || ENV["SECONDARY_UPSTREAM"]

    raise "You must provide both PRIMARY_UPSTREAM and SECONDARY_UPSTREAM URLs" if @primary.nil? || @secondary.nil? 
    super 
  end

  def forward_request(request)
    primary_response, secondary_response = RequestForwarder.mirror_to(@primary, @secondary, request)
    
    # log comparison of the two responses
    logger.info("stats: " + ResponseComparator.compare(primary_response, secondary_response).to_s )
    
    [primary_response.status, primary_response.headers, primary_response.body]
  end
  
  route :get, :put, :patch, :post, :delete, :head, :options, '/*' do
    forward_request(request)
  end
    
end