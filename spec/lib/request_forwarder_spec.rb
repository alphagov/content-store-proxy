require "spec_helper"
require "request_forwarder"

RSpec.describe RequestForwarder do
  describe "forward_to" do
    let(:mock_connection) { double("connection") }
    let(:mock_request) { double("mock request") }
    let(:mock_response) { double("mock response", headers: {}, body: mock_response_body) }
    let(:mock_response_body) { "mock response body" }

    before do
      allow(described_class).to receive(:new_connection).with("given url").and_return(mock_connection)
      allow(described_class).to receive(:send_to).with(mock_connection, mock_request).and_return(mock_response)
      allow(mock_response).to receive(:body=)
    end

    it "creates a new connection to the given upstream url" do
      expect(described_class).to receive(:new_connection).with("given url").and_return(mock_connection)
      described_class.forward_to("given url", mock_request)
    end

    it "sends the request to the new connection" do
      expect(described_class).to receive(:send_to).with(mock_connection, mock_request).and_return(mock_response)
      described_class.forward_to("given url", mock_request)
    end

    it "returns the response" do
      expect(described_class.forward_to("given url", mock_request)).to eq(mock_response)
    end

    describe "the returned response" do
      let(:returned_response) { described_class.forward_to("given url", mock_request) }
      
      it "has the X-Response-Time header set" do
        expect(returned_response.headers["X-Response-Time"]).not_to be_nil
      end
      
      it "has Content-Length header set to the length of the body" do
        expect(returned_response.headers["Content-Length"]).to eq("18")
      end

      it "has no Transfer-Encoding header" do
        expect(returned_response.headers.keys).to_not include("Transfer-Encoding")
      end

      context "when the response body is a stream" do
        let(:mock_response_body) { double(IO, read: "stream read into a string", size: 18) }
        
        it "processes the streaming body" do
          expect(described_class).to receive(:process_streaming_body)
          described_class.forward_to("given url", mock_request)
        end

        it "has Content-Length header set to the length of the body" do
          expect(returned_response.headers["Content-Length"]).to eq("18")
        end
  
        it "has no Transfer-Encoding header" do
          expect(returned_response.headers.keys).to_not include("Transfer-Encoding")
        end
      end
    end
  end

  describe ".process_streaming_body" do
    let(:mock_response) { double("response", body: double(IO, read: "stream read into a string")) }

    it "replaces the body with the full stream contents, plus a newline" do
      expect(mock_response).to receive(:body=).with("stream read into a string\n")
      described_class.process_streaming_body(mock_response)
    end
  end

  describe ".mirror_to" do
    let(:primary_upstream) { "primary upstream" }
    let(:secondary_upstream) { "secondary upstream" }
    let(:primary_response) { "primary response" }
    let(:secondary_response) { "secondary response" }
    
    before do
      allow(described_class).to receive(:forward_to).with(primary_upstream, "incoming request").and_return(primary_response)
      allow(described_class).to receive(:forward_to).with(secondary_upstream, "incoming request").and_return(secondary_response)
    end

    it "forwards the incoming request to the primary_upstream" do
      expect(described_class).to receive(:forward_to).with(primary_upstream, "incoming request").and_return(primary_response)
      described_class.mirror_to(primary_upstream, secondary_upstream, "incoming request")
    end
    
    it "forwards the incoming request to the secondary_upstream" do
      expect(described_class).to receive(:forward_to).with(secondary_upstream, "incoming request").and_return(secondary_response)
      described_class.mirror_to(secondary_upstream, secondary_upstream, "incoming request")
    end
    
    it "returns an array of the primary & secondary responses" do
      expect(described_class.mirror_to(primary_upstream, secondary_upstream, "incoming request")).to eq([primary_response, secondary_response])
    end
  end

  describe ".new_connection" do
    before do
      allow(Faraday).to receive(:new).with(url: "url").and_return("mock new Faraday connection")
    end

    it "creates a Faraday connection to the given URL" do
      expect(Faraday).to receive(:new).with(url: "url") 
      described_class.new_connection("url")
    end

    it "returns the new Faraday connection" do
      expect(described_class.new_connection("url")).to eq("mock new Faraday connection")
    end
  end

  describe ".send_to" do
    let(:mock_request) { double(request_method: "GIVEN_VERB", path: "/given/path", params: "params", body: "body") }
    let(:mock_connection) { double(Faraday::Connection) }

    before do
      allow(mock_connection).to receive(:given_verb).and_return "mock response"
    end

    it "sends the given requests HTTP verb to the connection as a method, passing the request path" do
      expect(mock_connection).to receive(:given_verb).with("/given/path")
      described_class.send_to(mock_connection, mock_request)
    end

    it "returns the response" do
      expect(described_class.send_to(mock_connection, mock_request)).to eq("mock response")
    end

    describe "the outgoing request" do
      let(:outgoing_request) { Faraday::Request.new }

      before do
        allow(mock_connection).to receive(:given_verb).and_yield(outgoing_request)
        allow(described_class).to receive(:set_content_headers)
        allow(described_class).to receive(:headers_from)
      end

      it "copies headers from the incoming request" do
        expect(described_class).to receive(:headers_from).with(mock_request).and_return( {"incoming header" => "value"} )
        expect(outgoing_request).to receive(:headers=).with({"incoming header" => "value"})
        described_class.send_to(mock_connection, mock_request)
      end

      it "sets the content headers" do
        expect(described_class).to receive(:set_content_headers).with(outgoing_request)
        described_class.send_to(mock_connection, mock_request)
      end

      it "copies the body from the incoming request" do
        expect(outgoing_request).to receive(:body=).with("body")
        described_class.send_to(mock_connection, mock_request)
      end
    end
  end

  describe ".headers_from" do
    context "given a request with Rack-parsed headers" do
      let(:incoming_request) do
        double({
          env: {
            "HTTP_HOST" => "my.host",
            "HTTP_TRANSFER_ENCODING" => "chunked",
            "NOT_A_HEADER" => "some other value",
          }
        })
      end

      let(:returned_value) { described_class.headers_from(incoming_request) }

      it "includes only the env vars where the key starts with HTTP_" do
        expect(returned_value.keys.size).to eq(2)
      end
      
      it "transforms the key to capital case and strips off the leading HTTP_" do
        expect(returned_value).to eq({
          "Host" => "my.host",
          "Transfer-Encoding" => "chunked",
        })
      end
    end
  end
end 