require 'spec_helper'
require 'rack/test'
require 'json'

RSpec.describe 'Forwarding service' do
  include Rack::Test::Methods

  let(:app) { Sinatra::Application }
  let(:primary_response_body) { 'Primary response body' }
  let(:secondary_response_body) { 'Secondary response body' }

  before(:each) do
    ENV['UPSTREAM_SERVICE_1'] = 'http://localhost:8081'
    ENV['UPSTREAM_SERVICE_2'] = 'http://localhost:8082'
  end

  describe 'POST requests' do
    let(:primary_response_status) { 200 }
    let(:secondary_response_status) { 201 }

    it 'forwards the request to the primary upstream service' do
      stub_request(:post, ENV['UPSTREAM_SERVICE_1']).to_return(status: primary_response_status, body: primary_response_body)

      post '/foo'

      expect(last_response.status).to eq(primary_response_status)
      expect(last_response.body).to eq(primary_response_body)
    end

    it 'forwards the request to the secondary upstream service if the primary returns an error' do
      stub_request(:post, ENV['UPSTREAM_SERVICE_1']).to_return(status: 500)
      stub_request(:post, ENV['UPSTREAM_SERVICE_2']).to_return(status: secondary_response_status, body: secondary_response_body)

      post '/foo'

      expect(last_response.status).to eq(secondary_response_status)
      expect(last_response.body).to eq(secondary_response_body)
    end

    it 'returns the primary response even if the secondary response returns an error' do
      stub_request(:post, ENV['UPSTREAM_SERVICE_1']).to_return(status: primary_response_status, body: primary_response_body)
      stub_request(:post, ENV['UPSTREAM_SERVICE_2']).to_return(status: 500)

      post '/foo'

      expect(last_response.status).to eq(primary_response_status)
      expect(last_response.body).to eq(primary_response_body)
    end

    it 'logs the status code, response time and body size of the two responses' do
      allow_any_instance_of(Faraday::Adapter::Test::Stubs).to receive(:post).and_return(double(status: primary_response_status, body: primary_response_body), double(status: secondary_response_status, body: secondary_response_body))

      expect_any_instance_of(Logger).to receive(:info).with(/Primary response \(#{primary_response_status}\) received in \d+\.\d+ seconds and \d+ bytes/)
      expect_any_instance_of(Logger).to receive(:info).with(/Secondary response \(#{secondary_response_status}\) received in \d+\.\d+ seconds and \d+ bytes/)

      post '/foo'
    end

    it 'logs an error if there is a problem forwarding the request' do
      allow(Faraday).to receive(:new).and_raise(StandardError.new('Could not connect'))

      expect_any_instance_of(Logger).to receive(:error).with(/Could not connect/)

      post '/foo'
    end

    it 'logs the first difference in the response bodies if they differ' do
      allow_any_instance_of(Faraday::Adapter::Test::Stubs).to receive(:post).and_return(double(status: primary_response_status, body: 'Primary response body'), double(status: secondary_response_status, body: 'Secondary response body'))

      expect_any_instance_of(Logger).to receive(:info).with(/Primary response \(#{primary_response_status}\) differs from secondary response \(#{secondary_response}\)/)
    end
  end
