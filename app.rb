# frozen_string_literal: true

require "sinatra/base"
require "sinatra/multi_route"

require "./lib/request_forwarder"
require "./lib/response_comparator"
require "./lib/comparison_logger"

class ContentStoreProxyApp < Sinatra::Base
  register Sinatra::MultiRoute

  def initialize(primary_upstream: nil, secondary_upstream: nil, comparison_sample_pct: nil, secondary_timeout: nil)
    @primary = primary_upstream || ENV["PRIMARY_UPSTREAM"]
    @secondary = secondary_upstream || ENV["SECONDARY_UPSTREAM"]
    @comparison_sample_pct = comparison_sample_pct || ENV["COMPARISON_SAMPLE_PCT"].to_i
    @secondary_timeout = secondary_timeout || ENV["SECONDARY_TIMEOUT_SECONDS"]
    @secondary_timeout = @secondary_timeout.to_f.round(2) unless @secondary_timeout.nil?

    raise "You must provide both PRIMARY_UPSTREAM and SECONDARY_UPSTREAM URLs" if @primary.nil? || @secondary.nil?

    super
  end

  def forward_request(request)
    primary_response, secondary_response = RequestForwarder.mirror_to(@primary, @secondary, request, secondary_timeout: @secondary_timeout)

    # Log comparison of the two responses, but only the given percentage of them get the full comparison.
    # This is to prevent the issue seen under full production load, where the CPU usage of the proxy app
    # maxes out its limit
    comparison = ResponseComparator.new(primary_response, secondary_response, @comparison_sample_pct).compare
    ComparisonLogger.log(comparison, request)
    [primary_response.status, primary_response.headers, primary_response.body]
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
