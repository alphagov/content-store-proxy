# frozen_string_literal: true

require "spec_helper"
require "request_forwarder"

RSpec.describe RequestForwarder do
  describe "forward_to" do
    let(:mock_connection) { instance_double(Faraday::Connection) }
    let(:mock_request) { instance_double(Rack::Request) }
    let(:mock_payload) { "payload" }
    let(:mock_response) { instance_double(Rack::Response, headers: {}, body: mock_response_body) }
    let(:mock_response_body) { "mock response body" }

    before do
      allow(described_class).to receive(:new_connection).with("given url").and_return(mock_connection)
      allow(described_class).to receive(:send_to).with(mock_connection, mock_request,
                                                       mock_payload).and_return(mock_response)
      allow(mock_response).to receive(:body=)
    end

    it "creates a new connection to the given upstream url" do
      expect(described_class).to receive(:new_connection).with("given url")
      described_class.forward_to("given url", mock_request, "payload")
    end

    it "sends the request to the new connection with the given payload" do
      expect(described_class).to receive(:send_to).with(mock_connection, mock_request,
                                                        "payload")
      described_class.forward_to("given url", mock_request, "payload")
    end

    it "returns the response" do
      expect(described_class.forward_to("given url", mock_request, "payload")).to eq(mock_response)
    end

    describe "the returned response" do
      let(:returned_response) { described_class.forward_to("given url", mock_request, "payload") }

      it "has the X-Response-Time header set" do
        expect(returned_response.headers["X-Response-Time"]).not_to be_nil
      end

      it "has Content-Length header set to the length of the body" do
        expect(returned_response.headers["Content-Length"]).to eq("18")
      end

      it "has no Transfer-Encoding header" do
        expect(returned_response.headers.keys).not_to include("Transfer-Encoding")
      end

      context "when the response body is a stream" do
        let(:mock_response_body) { StringIO.new("stream read into a string") }

        it "processes the streaming body" do
          expect(described_class).to receive(:process_streaming_body)
          described_class.forward_to("given url", mock_request, "payload")
        end

        it "has Content-Length header set to the length of the body" do
          expect(returned_response.headers["Content-Length"]).to eq("25")
        end

        it "has no Transfer-Encoding header" do
          expect(returned_response.headers.keys).not_to include("Transfer-Encoding")
        end
      end
    end
  end

  describe ".process_streaming_body" do
    let(:mock_response) { instance_double(Rack::Response, body: StringIO.new("stream read into a string")) }

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
    let(:mock_request) { instance_double(Rack::Request, body: "payload") }

    before do
      allow(described_class).to receive(:payload_as_string).and_return("payload")
      allow(described_class).to receive(:forward_to).with(primary_upstream, mock_request,
                                                          "payload").and_return(primary_response)
      allow(described_class).to receive(:forward_to).with(secondary_upstream, mock_request,
                                                          "payload").and_return(secondary_response)
    end

    it "extracts the payload as a string" do
      expect(described_class).to receive(:payload_as_string).with("payload")
      described_class.mirror_to(primary_upstream, secondary_upstream, mock_request)
    end

    it "forwards the incoming request to the primary_upstream" do
      expect(described_class).to receive(:forward_to).with(primary_upstream, mock_request,
                                                           "payload")
      described_class.mirror_to(primary_upstream, secondary_upstream, mock_request)
    end

    it "forwards the incoming request to the secondary_upstream" do
      expect(described_class).to receive(:forward_to).with(secondary_upstream, mock_request,
                                                           "payload")
      described_class.mirror_to(secondary_upstream, secondary_upstream, mock_request)
    end

    it "returns an array of the primary & secondary responses" do
      expect(described_class.mirror_to(primary_upstream, secondary_upstream,
                                       mock_request)).to eq([primary_response, secondary_response])
    end
  end

  describe ".payload_as_string" do
    context "when given a string" do
      let(:body) { "a string" }

      it "returns the string" do
        expect(described_class.payload_as_string(body)).to eq("a string")
      end
    end

    context "when given a stream" do
      let(:body) { StringIO.new("payload") }

      it "reads the body and returns the resulting string" do
        expect(described_class.payload_as_string(body)).to eq("payload")
      end
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
    let(:given_verb) { "get" }
    let(:mock_request) { instance_double(Rack::Request, request_method: given_verb, path: "/given/path", params: { "param1" => "value1" }, query_string: "param1=value1", body: "body") }
    let(:mock_connection) { instance_double(Faraday::Connection) }

    before do
      allow(mock_connection).to receive(given_verb).and_return "mock response"
    end

    it "sends the given requests HTTP verb to the connection as a method, passing the request path with any query string added" do
      expect(mock_connection).to receive(given_verb).with("/given/path?param1=value1")
      described_class.send_to(mock_connection, mock_request, "payload")
    end

    it "returns the response" do
      expect(described_class.send_to(mock_connection, mock_request, "payload")).to eq("mock response")
    end

    describe "the outgoing request" do
      let(:outgoing_request) { Faraday::Request.new }

      before do
        allow(mock_connection).to receive(given_verb).and_yield(outgoing_request)
        allow(described_class).to receive(:set_content_headers)
        allow(described_class).to receive(:headers_from).and_return({ "incoming header" => "value" })
      end

      it "copies headers from the incoming request" do
        expect(described_class).to receive(:headers_from).with(mock_request)
        expect(outgoing_request).to receive(:headers=).with({ "incoming header" => "value" })
        described_class.send_to(mock_connection, mock_request, "payload")
      end

      it "sets the content headers" do
        expect(described_class).to receive(:set_content_headers).with(outgoing_request)
        described_class.send_to(mock_connection, mock_request, "payload")
      end

      it "copies the body from the incoming request" do
        expect(outgoing_request).to receive(:body=).with("payload")
        described_class.send_to(mock_connection, mock_request, "payload")
      end
    end
  end

  describe ".copy_header?" do
    context "when given a name starting with HTTP_" do
      context "and it's not HTTP_HOST" do
        it "returns true" do
          expect(described_class.copy_header?("HTTP_HEADER_NAME")).to eq(true)
        end
      end

      context "and it is HTTP_HOST" do
        it "returns false" do
          expect(described_class.copy_header?("HTTP_HOST")).to eq(false)
        end
      end
    end

    context "when given a name that does not start with HTTP_" do
      context "and it's not CONTENT_TYPE" do
        it "returns false" do
          expect(described_class.copy_header?("HEADER_NAME")).to eq(false)
        end
      end

      context "and it is CONTENT_TYPE" do
        it "returns true" do
          expect(described_class.copy_header?("CONTENT_TYPE")).to eq(true)
        end
      end
    end
  end

  describe ".headers_from" do
    context "when given a request with Rack-parsed headers" do
      let(:incoming_request) do
        instance_double(Rack::Request,
                        env: {
                          "HTTP_HOST" => "my.host",
                          "HTTP_TRANSFER_ENCODING" => "chunked",
                          "NOT_A_HEADER" => "some other value",
                          "CONTENT_TYPE" => "application/json",
                        })
      end

      let(:returned_value) { described_class.headers_from(incoming_request) }

      context "when copy_header? returns true" do
        before do
          allow(described_class).to receive(:copy_header?).and_return(false, true, false, false)
        end

        it "only includes the env vars where copy_header? returns true" do
          expect(returned_value.keys.size).to eq(1)
        end
      end

      it "transforms the keys to capital case and strips off any leading HTTP_" do
        expect(returned_value).to eq({
          "Transfer-Encoding" => "chunked",
          "Content-Type" => "application/json",
        })
      end
    end
  end
end
