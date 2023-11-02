# frozen_string_literal: true

require "spec_helper"
require "rack/test"
require "json"
require "faraday"
require "webmock/rspec"

require_relative "../app"

RSpec.describe "Forwarding service" do
  include Rack::Test::Methods

  let(:app) { ContentStoreProxyApp }
  let(:primary_response_body) { "Primary response body" }
  let(:secondary_response_body) { "Secondary response body" }
  let(:primary_response_status) { 200 }
  let(:secondary_response_status) { 201 }
  let(:primary_url) { "#{ENV['PRIMARY_UPSTREAM']}/foo" }
  let(:secondary_url) { "#{ENV['SECONDARY_UPSTREAM']}/foo" }

  before do
    ENV["PRIMARY_UPSTREAM"] = "http://localhost:8081"
    ENV["SECONDARY_UPSTREAM"] = "http://localhost:8082"

    stub_request(:get, primary_url).to_return(status: primary_response_status, body: primary_response_body)
    stub_request(:get, secondary_url).to_return(status: secondary_response_status, body: secondary_response_body)
  end

  describe "GET requests" do
    it "forwards the request to the primary upstream service" do
      get "/foo"

      expect(last_response.status).to eq(primary_response_status)
      expect(last_response.body).to eq(primary_response_body)
    end

    context "when the primary returns an error" do
      let(:primary_response_status) { 500 }

      it "forwards the request to the secondary upstream service" do
        get "/foo"
        expect(a_request(:get, secondary_url)).to have_been_made.once
      end

      it "still returns the primary status and body" do
        get "/foo"
        expect(last_response.status).to eq(primary_response_status)
        expect(last_response.body).to eq(primary_response_body)
      end
    end

    context "when the secondary returns an error" do
      let(:secondary_response_status) { 500 }

      it "forwards the request to the primary upstream service" do
        get "/foo"
        expect(a_request(:get, primary_url)).to have_been_made.once
      end

      it "still returns the primary status and body" do
        get "/foo"
        expect(last_response.status).to eq(primary_response_status)
        expect(last_response.body).to eq(primary_response_body)
      end
    end

    context "when an error is thrown in comparing the responses" do
      let(:mock_comparator) { instance_double(ResponseComparator) }

      before do
        allow(ResponseComparator).to receive(:new).and_return(mock_comparator)
        allow(mock_comparator).to receive(:compare).and_raise(TypeError, "This exception should be caught by the app")
      end

      it "does not allow the error to bubble out" do
        expect {
          get "/foo"
        }.not_to raise_error
      end

      it "still returns the primary status and body" do
        get "/foo"
        expect(last_response.status).to eq(primary_response_status)
        expect(last_response.body).to eq(primary_response_body)
      end
    end

    context "when the request has headers" do
      let(:headers) { { "HTTP_X_ARBITRARY_HEADER" => "X-A-H header value", "HTTP_ACCEPT" => "application/json" } }

      it "translates the given headers and passes them correctly to the primary upstream service" do
        get "/foo", {}, headers

        expect(WebMock).to have_requested(:get, primary_url)
          .with(
            headers: { "Accept" => "application/json", "X-Arbitrary-Header" => "X-A-H header value" },
          )
      end

      it "translates the given headers and passes them correctly to the secondary upstream service" do
        get "/foo", {}, headers

        expect(WebMock).to have_requested(:get, secondary_url)
          .with(
            headers: { "Accept" => "application/json", "X-Arbitrary-Header" => "X-A-H header value" },
          )
      end
    end
  end

  describe "POST requests" do
    let(:body) { { field1: "value 1", field2: "value 2" }.to_json }
    let(:headers) { { "HTTP_X_ARBITRARY_HEADER" => "X-A-H header value", "HTTP_ACCEPT" => "application/json" } }

    before do
      stub_request(:post, primary_url).to_return(status: primary_response_status, body: primary_response_body)
      stub_request(:post, secondary_url).to_return(status: secondary_response_status, body: secondary_response_body)
    end

    it "forwards the request with the given body to the primary upstream service" do
      post "/foo", body, headers

      expect(WebMock).to have_requested(:post, primary_url)
        .with(
          body:,
        )
    end

    it "translates the given headers and passes them correctly to the primary upstream service" do
      post "/foo", body, headers

      expect(WebMock).to have_requested(:post, primary_url)
        .with(
          body:,
          headers: { "Accept" => "application/json", "X-Arbitrary-Header" => "X-A-H header value" },
        )
    end

    it "forwards the request with the given body to the secondary upstream service" do
      post "/foo", body, headers

      expect(a_request(:post, secondary_url)
        .with(
          body:,
        )).to have_been_made
    end

    it "translates the given headers and passes them correctly to the secondary upstream service" do
      post "/foo", body, headers

      expect(WebMock).to have_requested(:post, secondary_url)
        .with(
          body:,
          headers: { "Accept" => "application/json", "X-Arbitrary-Header" => "X-A-H header value" },
        )
    end

    context "when the primary returns an error" do
      let(:primary_response_status) { 500 }

      it "forwards the request to the secondary upstream service" do
        post "/foo"
        expect(a_request(:post, secondary_url)).to have_been_made.once
      end

      it "still returns the primary status and body" do
        post "/foo"
        expect(last_response.status).to eq(primary_response_status)
        expect(last_response.body).to eq(primary_response_body)
      end
    end

    context "when the secondary returns an error" do
      let(:secondary_response_status) { 500 }

      it "forwards the request to the primary upstream service" do
        post "/foo"
        expect(a_request(:post, primary_url)).to have_been_made.once
      end

      it "still returns the primary status and body" do
        post "/foo"
        expect(last_response.status).to eq(primary_response_status)
        expect(last_response.body).to eq(primary_response_body)
      end
    end

    context "when the incoming request body is a stream" do
      let(:body_content) { "this is the contents of the stream, not the stream itself" }
      let(:body) { StringIO.new(body_content) }

      it "forwards the request with the read body to the primary upstream service" do
        post "/foo", body, headers

        expect(WebMock).to have_requested(:post, primary_url)
          .with(
            body: body_content,
          )
      end

      it "forwards the request with the read body to the secondary upstream service" do
        post "/foo", body, headers

        expect(a_request(:post, secondary_url)
          .with(
            body: body_content,
          )).to have_been_made
      end
    end
  end
end
