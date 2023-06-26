# frozen_string_literal: true

class ResponseComparator
  def self.compare(primary_response, secondary_response)
    {
      primary_response: response_stats(primary_response),
      secondary_response: response_stats(secondary_response),
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
    (obj1.keys + obj2.keys).uniq.reject { |k| obj1[k] == obj2[k] }
  rescue JSON::ParserError
    "N/A"
  end
end
