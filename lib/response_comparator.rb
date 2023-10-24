# frozen_string_literal: true

class ResponseComparator
  # The maximum difference in seconds between two updated_at timestamps
  # or two scheduled_publishing_delay_seconds values (which are
  # calculated "on arrival" by the ContentItem.create_or_update)
  # for the proxy to consider them "close enough to not warn about".
  # A small difference is acceptable as these timestamps are generated
  # automatically by the ORM layer on write, and the two requests often
  # complete either side of a second boundary as they run in parallel.
  MAX_TIME_DIFFERENCE = 2

  attr_accessor :primary_response, :secondary_response, :full_comparison_pct

  def initialize(primary_response, secondary_response, full_comparison_pct = 0)
    @primary_response = primary_response
    @secondary_response = secondary_response
    @full_comparison_pct = full_comparison_pct
  end

  def compare
    start = Time.now
    comparison = quick_comparison
    comparison.merge!(differences) if @secondary_response && full_comparison?(comparison, full_comparison_pct)
    comparison[:comparison_time_seconds] = Time.now - start
    comparison
  end

  def quick_comparison
    {
      primary_response: response_stats(@primary_response),
      secondary_response: @secondary_response ? response_stats(@secondary_response) : nil,
    }
  end

  def full_comparison?(comparison, full_pct)
    r = Random.rand(100)
    comparison.merge!(sample_percent: full_pct, r:)
    (r < full_pct)
  end

  def differences
    {
      first_difference: first_difference(@primary_response.body, @secondary_response.body),
      different_keys: different_keys(@primary_response.body, @secondary_response.body),
    }
  end

  def response_stats(response)
    stats = {
      status: response.status,
      body_size: response.body.size,
      time: response.headers["X-Response-Time"].to_f,
    }
    stats.merge!(location: response.headers["Location"]) if response.status == 303
    stats
  end

  def first_difference(string1, string2)
    # Binary search to find the first index where the slice of string1 is not
    # at the start of string2
    # Almost 1000 times faster for long strings (>250k characters)
    # on local testing when compared to naive iterate-and-compare-each-char
    i = (0..string1.length).bsearch { |n| string2.rindex(string1[0..n]) != 0 }

    # Just need to handle the edge case where string2 is string1 + some stuff on the end
    if i.nil? && (string2.length > string1.length)
      i = string1.length
    end

    i.nil? ? {} : { position: i, context: [string1[i - 5..i + 5], string2[i - 5..i + 5]] }
  end

  def different_keys(json_hash1, json_hash2)
    obj1 = JSON.parse(json_hash1)
    obj2 = JSON.parse(json_hash2)
    (obj1.keys + obj2.keys).uniq.reject do |k|
      obj1[k] == obj2[k] ||
        (k == "updated_at" && timestamps_close_enough(obj1[k], obj2[k], max_time_difference)) ||
        (k == "scheduled_publishing_delay_seconds" && integers_close_enough(obj1[k], obj2[k], max_time_difference))
    end
  rescue JSON::ParserError
    "N/A"
  end

  def integers_close_enough(int1, int2, max_diff)
    (int1 - int2).to_i.abs <= max_diff
  rescue ArgumentError, NoMethodError
    false
  end

  def timestamps_close_enough(str1, str2, max_diff)
    date1 = Time.iso8601(str1)
    date2 = Time.iso8601(str2)
    (date1 - date2).to_i.abs <= max_diff
  rescue ArgumentError
    false
  end

  # The constant is wrapped in a method to make it easily stubbable in
  # tests.
  def max_time_difference
    MAX_TIME_DIFFERENCE
  end
end
