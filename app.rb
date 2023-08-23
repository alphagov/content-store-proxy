# frozen_string_literal: true

require "sinatra/base"
require "sinatra/multi_route"
require "sinatra/custom_logger"
require "logger"
require "rack/logstasher"
require "gds_api/middleware/govuk_header_sniffer"

require "./lib/request_forwarder"
require "./lib/response_comparator"

class ContentStoreProxyApp < Sinatra::Base
  register Sinatra::MultiRoute
  helpers Sinatra::CustomLogger

  configure :development, :production do
    # disable rack common logger so we can use a JSON one
    set :logging, nil

    # JSON logstash logging for production env
    use Rack::Logstasher::Logger, Logger.new($stdout), extra_request_headers: { "GOVUK-Request-Id" => "govuk_request_id" }

    logger = Logger.new($stdout)
    logger.level = Logger::DEBUG # if development?
    set :logger, logger

    # HTTP headers that are passed on to subsequent apps
    use GdsApi::GovukHeaderSniffer, "HTTP_GOVUK_REQUEST_ID"
  end

  def initialize(primary_upstream: nil, secondary_upstream: nil)
    @primary = primary_upstream || ENV["PRIMARY_UPSTREAM"]
    @secondary = secondary_upstream || ENV["SECONDARY_UPSTREAM"]

    raise "You must provide both PRIMARY_UPSTREAM and SECONDARY_UPSTREAM URLs" if @primary.nil? || @secondary.nil?

    super
  end

  def forward_request(request)
    primary_response, secondary_response = RequestForwarder.mirror_to(@primary, @secondary, request)

    # log comparison of the two responses
    comparison = ResponseComparator.compare(primary_response, secondary_response)
    level = comparison[:first_difference].empty? ? :info : :warn
    log_as_json(level, { path: request.path, stats: comparison })

    [primary_response.status, primary_response.headers, primary_response.body]
  end

  def log_as_json(level, data = {})
    log_line = data.merge(level:, method: request.env["REQUEST_METHOD"], timestamp: Time.now.utc.iso8601).to_json
    # logger.send(level, log_line)
    puts log_line
  end

  get "/healthcheck/live" do
    [200, { "Content-Type" => "text/plain" }, "OK"]
  end

  get "/healthcheck/ready" do
    [200, { "Content-Type" => "text/plain" }, "OK"]
  end

  route :get, :put, :patch, :post, :delete, :head, :options, "/*" do
    forward_request(request)
  end
end
