
require 'sinatra'
require 'sinatra/multi_route'

require './lib/request_forwarder'
require './lib/response_comparator'

configure do
  set primary: ENV["PRIMARY_UPSTREAM"], secondary: ENV["SECONDARY_UPSTREAM"]

  raise "You must provide both PRIMARY_UPSTREAM and SECONDARY_UPSTREAM URLs" if settings.primary.nil? || settings.secondary.nil?
end

route :get, :put, :patch, :post, :delete, :head, :options, '/*' do
  primary_response, secondary_response = RequestForwarder.mirror_to(settings.primary, settings.secondary, request)

  # log comparison of the two responses
  logger.info("stats: " + ResponseComparator.compare(primary_response, secondary_response).to_s )

  [primary_response.status, primary_response.headers, primary_response.body]
end

