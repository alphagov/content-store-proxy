class ComparisonLogger
  attr_accessor :comparison, :request

  def initialize(comparison: , request:)
    @comparison = comparison
    @request = request
  end

  def log
    line = {
      timestamp: Time.now.utc.iso8601,
      level: level,
      method: @request.request_method,
      path: @request.path,
      query_string: @request.query_string,
      stats: @comparison,
    }
    puts line.to_json
  end

  def level
    if (@comparison[:different_keys].empty? || @comparison[:different_keys] == "N/A") &&
        responses_have_the_same?(:status) &&
        responses_have_the_same?(:body_size)
      :info
    else
      :warn
    end
  end

  def responses_have_the_same?(field)
    @comparison.dig(:stats, :primary_response, field) == @comparison.dig(:stats, :secondary_response, field)
  end
end