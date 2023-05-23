# frozen_string_literal: true

class ResponseComparator
  def self.compare(primary_response, secondary_response)
    {
      primary_response: response_stats(primary_response),
      secondary_response: response_stats(secondary_response),
      first_difference: first_difference(primary_response.body, secondary_response.body),
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
    i = 0
    i += 1 while string1[i] == string2[i] && i < string1.size

    if i < string1.size || i < string2.size
      { position: i, context: [string1[i - 5..i + 5], string2[i - 5..i + 5]] }
    else
      {}
    end
  end
end
