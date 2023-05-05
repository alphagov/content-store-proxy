

run do |env|
  primary_host = env["PRIMARY_UPSTREAM"]
  conn = Faraday::Connection.new primary_host
  conn.send(request.request_method.downcase) { |req| setup_request(req, request) }
end

  def rewrite_response(triplet)
    status, headers, body = triplet
    headers['X-Forwarded-By'] = 'content-store-proxy'

    # if you proxy depending on the backend, it appears that content-length isn't calculated correctly
    # resulting in only partial responses being sent to users
    # you can remove it or recalculate it here
    headers["content-length"] = body.size

    triplet
  end
end