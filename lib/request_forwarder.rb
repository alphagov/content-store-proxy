require 'faraday'

class RequestForwarder

  def self.mirror_to(primary_upstream, secondary_upstream, incoming_request)
    # forward to primary upstream
    primary_thread = Thread.new { forward_to(primary_upstream, incoming_request) }
    # forward to secondary upstream
    secondary_thread = Thread.new { forward_to(secondary_upstream, incoming_request) }

    primary_thread.join
    secondary_thread.join
    primary_response = primary_thread.value
    secondary_response = secondary_thread.value 
    [primary_response, secondary_response]
  end

  def self.forward_to(upstream, incoming_request)
    start_time = Time.now
    response = send_to(new_connection(upstream), incoming_request)
    
    response.headers['X-Response-Time'] = (Time.now - start_time).to_s
    set_content_headers(response)
    response
  end

private

  def self.new_connection(url)
    Faraday.new( url: url )
  end

  def self.set_content_headers(obj)
    # we always send a full body - if we're given a stream,
    # that's more complex to deal with, so let's just read it into a String
    process_streaming_body(obj) if obj.body.respond_to?(:read)

    # These two headers have to be in agreement about whether its a chunked
    # stream (=> no length), or a string of length X (=> not chunked)
    obj.headers.delete('Transfer-Encoding')
    obj.headers['Content-Length'] ||= obj.body.size.to_s
  end

  def self.process_streaming_body(obj)
    obj.body = obj.body.read + "\n"
  end

  def self.send_to(connection, incoming_request)
    connection.send(incoming_request.request_method.downcase, incoming_request.path) do |req|
      req.headers = headers_from(incoming_request)
      # We must delete Host header, otherwise the upstream request
      # will return a 503
      req.headers.delete("Host")
      req.params = incoming_request.params
      req.body = incoming_request.body.dup

      set_content_headers(req)
    end
  end

  def self.headers_from(incoming_request)
    incoming_request.env.select { |name, _| name.start_with?("HTTP_") }.map do |header, value|
      [header[5..-1].split("_").map(&:capitalize).join('-'), value]
    end.compact.to_h
  end
end