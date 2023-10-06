# frozen_string_literal: true

require "sinatra/base"
require "sinatra/multi_route"

require "./lib/request_forwarder"
require "./lib/response_comparator"

class ContentStoreProxyApp < Sinatra::Base
  register Sinatra::MultiRoute

  def initialize(primary_upstream: nil, secondary_upstream: nil, comparison_sample_pct: nil)
    @primary = primary_upstream || ENV["PRIMARY_UPSTREAM"]
    @secondary = secondary_upstream || ENV["SECONDARY_UPSTREAM"]
    @comparison_sample_pct = comparison_sample_pct || ENV["COMPARISON_SAMPLE_PCT"].to_i

    raise "You must provide both PRIMARY_UPSTREAM and SECONDARY_UPSTREAM URLs" if @primary.nil? || @secondary.nil?

    super
  end

  def forward_request(request)
    primary_response, secondary_response = RequestForwarder.mirror_to(@primary, @secondary, request)

    # log comparison of the two responses
    comparison_type = rand(100) <= @comparison_sample_pct ? :quick : :full
    log_comparison ResponseComparator.compare(primary_response, secondary_response, comparison_type)
    [primary_response.status, primary_response.headers, primary_response.body]
  end

  get "/healthcheck/live" do
    [200, { "Content-Type" => "text/plain" }, "OK"]
  end

  get "/healthcheck/ready" do
    [200, { "Content-Type" => "text/plain" }, "OK"]
  end

  def log_comparison(comparison)
    line = {
      timestamp: Time.now.utc.iso8601,
      level: log_level(comparison),
      method: env["REQUEST_METHOD"],
      path: request.path,
      query_string: env["QUERY_STRING"],
      stats: comparison,
    }
    puts line.to_json
  end

  def log_level(comparison)
    if (comparison[:different_keys].empty? || comparison[:different_keys] == "N/A") &&
        matches?(comparison, :status) &&
        matches?(comparison, :body_size)
      :info
    else
      :warn
    end
  end

  def matches?(comparison, field)
    comparison.dig(:stats, :primary_response, field) == comparison.dig(:stats, :secondary_response, field)
  end

  route :get, :put, :patch, :post, :delete, :head, :options, "/*" do
    forward_request(request)
  end
end
