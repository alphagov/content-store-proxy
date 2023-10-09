# frozen_string_literal: true

class ResponseComparator
  # The maximum difference in seconds between two updated_at timestamps
  # for the proxy to consider them "close enough to not warn about".
  # A small difference is acceptable as these timestamps are generated
  # automatically by the ORM layer on write, and the two requests often
  # complete either side of a second boundary as they run in parallel.
  MAX_UPDATED_AT_DIFFERENCE = 2

  def self.compare(primary_response, secondary_response, full_comparison_pct = 0)
    start = Time.now
    comparison = quick_comparison(primary_response, secondary_response)
    comparison.merge!(differences(primary_response, secondary_response)) if full_comparison?(comparison, full_comparison_pct)
    comparison[:comparison_time_seconds] = Time.now - start
    comparison
  end

  def self.quick_comparison(primary_response, secondary_response)
    {
      primary_response: response_stats(primary_response),
      secondary_response: response_stats(secondary_response),
      first_difference: "N/A",
      different_keys: "N/A",
    }
  end

  def self.full_comparison?(comparison, full_pct)
    srand
    r = Random.rand(99)
    full = (full_pct == 100 || r < full_pct)
    comparison.merge!(sample_percent: full_pct, r:)
    full
  end

  def self.differences(primary_response, secondary_response)
    {
      first_difference: first_difference(primary_response.body, secondary_response.body),
      different_keys: different_keys(primary_response.body, secondary_response.body),
    }
  end

  def self.response_stats(response)
    {
      status: response.status,
      body_size: response.body.size,
      time: response.headers["X-Response-Time"].to_f,
    }
  end

  def self.first_difference(string1, string2)
    if string1 == string2
      {}
    else
      i = (0...string1.size).find { |j| string1[j] != string2[j] } || string1.size
      { position: i, context: [string1[i - 5..i + 5], string2[i - 5..i + 5]] }
    end
  end

  def self.different_keys(json_hash1, json_hash2)
    obj1 = JSON.parse(json_hash1)
    obj2 = JSON.parse(json_hash2)
    (obj1.keys + obj2.keys).uniq.reject do |k|
      obj1[k] == obj2[k] ||
        (k == "updated_at" && timestamps_close_enough(obj1[k], obj2[k], max_updated_at_difference))
    end
  rescue JSON::ParserError
    "N/A"
  end

  def self.timestamps_close_enough(str1, str2, max_diff)
    date1 = Time.iso8601(str1)
    date2 = Time.iso8601(str2)
    (date1 - date2).to_i.abs <= max_diff
  rescue ArgumentError
    false
  end

  # The constant is wrapped in a method to make it easily stubbable in
  # tests.
  def self.max_updated_at_difference
    MAX_UPDATED_AT_DIFFERENCE
  end
end
