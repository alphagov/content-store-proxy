require "typhoeus"

class TyphoeusRequestManager
  attr_accessor :hydra, :responses

  def initialize(max_concurrency: 20, hydra: nil)
    @hydra = hydra || Typhoeus::Hydra.new(max_concurrency:)

    # Have to use a Queue for thread-safety (Array is not thread-safe)
    @responses = Queue.new
  end

  def run(max_concurrency: 20)
    begin
      @hydra.max_concurrency = max_concurrency
      @hydra.run
    ensure
      @responses.close
      print "\n"
    end
    Array.new(@responses.size) { @responses.pop }
  end

  def get(url, headers = {})
    request = construct_request(url, headers:)
    request.on_complete do |response|
      responses << summary(response)
      print "#{@responses.size} complete\r"
    end
    @hydra.queue(request)
  end

private

  def summary(response)
    {
      url: response.effective_url,
      time: response.total_time,
      status: response.response_code,
    }
  end

  def construct_request(url, method: :get, headers: {})
    Typhoeus::Request.new(
      url,
      method:,
      headers:,
      followlocation: true,
    )
  end
end
