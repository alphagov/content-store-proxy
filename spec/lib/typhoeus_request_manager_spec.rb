require "spec_helper"
require "typhoeus_request_manager"

RSpec.describe TyphoeusRequestManager do
  let(:request_manager) { described_class.new(hydra: mock_hydra) }
  let(:mock_hydra) { instance_double(Typhoeus::Hydra) }

  before do
    allow(mock_hydra).to receive(:queue)
  end

  describe "get" do
    let(:headers) { { "header_name" => "value" } }
    let(:mock_request) { instance_double(Typhoeus::Request) }

    before do
      allow(Typhoeus::Request).to receive(:new).and_return(mock_request)
      allow(mock_request).to receive(:on_complete)
    end

    it "makes a new Typhoeus::Request with correct parameters" do
      expect(Typhoeus::Request).to receive(:new).with("my_url", method: :get, headers:, followlocation: true)
      request_manager.get("my_url", headers)
    end

    it "sets up the on_complete block on the request" do
      expect(mock_request).to receive(:on_complete)
      request_manager.get("my_url", headers)
    end
  end

  describe "run" do
    before do
      allow(mock_hydra).to receive(:run)
      allow(mock_hydra).to receive(:max_concurrency=)
    end

    it "sets the hydra's max_concurrency to the given value" do
      expect(mock_hydra).to receive(:max_concurrency=).with(33)
      request_manager.run(max_concurrency: 33)
    end

    it "runs the hydra" do
      expect(mock_hydra).to receive(:run)
      request_manager.run(max_concurrency: 33)
    end

    it "returns an Array" do
      expect(request_manager.run(max_concurrency: 33)).to be_a(Array)
    end
  end
end
