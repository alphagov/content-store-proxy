require_relative "./typhoeus_request_manager"

class LoadTester
  attr_accessor :request_manager

  def initialize(request_manager: nil, max_concurrency: 20)
    @request_manager = request_manager || default_request_manager(max_concurrency:)
  end

  # GET each one of the given URLs, once, passing the given headers,
  # limiting the number of simultaneous requests to the given max_concurrency,
  # and return stats about the responses
  def run(urls, headers: {}, max_concurrency: 20)
    results = get_responses(urls, max_concurrency:, headers:) || []
    report_stats(results)
  end

  def get_responses(urls, max_concurrency: 20, headers: {})
    urls.each do |url|
      @request_manager.get(url, headers:)
    end

    @request_manager.run(max_concurrency:)
  end

private

  def default_request_manager(max_concurrency: 20)
    TyphoeusRequestManager.new(max_concurrency:)
  end

  def report_stats(responses, time_threshold: 4.0)
    number_over_threshold = responses.map { |r| r[:time] }.select { |t| t >= time_threshold }.count
    pct_over_threshold = number_over_threshold * 100.0 / responses.size
    statuses = responses.map { |r| r[:status] }.tally
    server_errors = responses.count { |r| r[:status].to_s.start_with?("5") }
    sum_time = responses.sum { |r| r[:time] }
    mean_time = responses.size.positive? ? sum_time / responses.size : nil
    variance = responses.size.positive? ? responses.sum { |r| (r[:time] - mean_time)**2 } / responses.size : nil

    {
      number_of_responses: responses.size,
      response_times: {
        mean: mean_time,
        variance:,
        std_dev: variance ? Math.sqrt(variance) : nil,
        threshold: "#{time_threshold}s",
        number_over_threshold:,
        pct_over_threshold: "#{pct_over_threshold.round(2)}%",
      },
      statuses:,
      server_errors:,
    }
  end
end
