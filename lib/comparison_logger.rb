class ComparisonLogger
  def self.log(comparison, request)
    puts line(comparison, request)
  end

  def self.line(comparison, request)
    log_structure(comparison, request).to_json
  end

  def self.log_structure(comparison, request)
    {
      timestamp: Time.now.utc.iso8601,
      level: log_level(comparison),
      method: request.env["REQUEST_METHOD"],
      path: request.path,
      query_string: request.env["QUERY_STRING"],
      stats: comparison,
    }
  end

  def self.log_level(comparison)
    if (comparison[:different_keys].nil? || comparison[:different_keys] == [] || comparison[:different_keys] == "N/A") &&
        matches?(comparison, :status) &&
        matches?(comparison, :body_size)
      :info
    else
      :warn
    end
  end

  def self.matches?(comparison, field)
    comparison.dig(:primary_response, field) == comparison.dig(:secondary_response, field)
  end
end
