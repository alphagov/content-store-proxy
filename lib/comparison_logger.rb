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
    level = :warn
    if (comparison[:different_keys].nil? || comparison[:different_keys] == [] || comparison[:different_keys] == "N/A") &&
        matches?(comparison, :status)
      if comparison.dig(:primary_response, :status) == 303 && location_paths_match?(comparison)
        level = :info
      elsif matches?(comparison, :body_size)
        level = :info
      end
    end
    level
  end

  def self.matches?(comparison, field)
    comparison.dig(:primary_response, field) == comparison.dig(:secondary_response, field)
  end

  def self.location_paths_match?(comparison)
    primary_location = comparison.dig(:primary_response, :location).to_s.sub(/http:\/\/[^\/]+/, "")
    secondary_location = comparison.dig(:secondary_response, :location).to_s.sub(/http:\/\/[^\/]+/, "")
    primary_location == secondary_location
  end
end
