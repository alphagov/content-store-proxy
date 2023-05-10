require 'spec_helper'
require 'rack/test'
require 'json'
require 'faraday'
require 'webmock/rspec'

require_relative '../app'

RSpec.describe 'Forwarding service' do
  include Rack::Test::Methods

  let(:app) { ContentStoreProxyApp }
  let(:primary_response_body) { 'Primary response body' }
  let(:secondary_response_body) { 'Secondary response body' }
  let(:primary_response_status) { 200 }
  let(:secondary_response_status) { 201 }
  let(:primary_url) { ENV['PRIMARY_UPSTREAM'] + '/foo' }
  let(:secondary_url) { ENV['SECONDARY_UPSTREAM'] + '/foo' }

  before(:each) do
    ENV['PRIMARY_UPSTREAM'] = 'http://localhost:8081'
    ENV['SECONDARY_UPSTREAM'] = 'http://localhost:8082'

    stub_request(:get, primary_url).to_return(status: primary_response_status, body: primary_response_body)
    stub_request(:get, secondary_url).to_return(status: secondary_response_status, body: secondary_response_body)
  end
  

  describe 'GET requests' do

    it 'forwards the request to the primary upstream service' do
      get '/foo'

      expect(last_response.status).to eq(primary_response_status)
      expect(last_response.body).to eq(primary_response_body)
    end

    context 'when the primary returns an error' do
      let(:primary_response_status) { 500 }

      it 'forwards the request to the secondary upstream service' do
        get '/foo'
        expect(a_request(:get, secondary_url)).to have_been_made.once
      end

      it 'still returns the primary status and body' do
        get '/foo'
        expect(last_response.status).to eq(primary_response_status)
        expect(last_response.body).to eq(primary_response_body)
      end
    end

    context 'when the secondary returns an error' do
      let(:secondary_response_status) { 500 }

      it 'forwards the request to the primary upstream service' do
        get '/foo'
        expect(a_request(:get, primary_url)).to have_been_made.once
      end

      it 'still returns the primary status and body' do
        get '/foo'
        expect(last_response.status).to eq(primary_response_status)
        expect(last_response.body).to eq(primary_response_body)
      end
    end
  end
end