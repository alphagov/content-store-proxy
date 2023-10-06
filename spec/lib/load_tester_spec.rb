require "spec_helper"

require "load_tester"
require "typhoeus_request_manager"

RSpec.describe LoadTester do
  let(:load_tester) { described_class.new(request_manager:) }

  let(:request_manager) { instance_double(TyphoeusRequestManager) }
  let(:mock_response_1) { mock("response1") }
  let(:mock_response_2) { mock("response2") }

  describe "#run" do
    before do
      allow(request_manager).to receive(:run)
      allow(request_manager).to receive(:get)
    end

    context "when given an array of URLs" do
      let(:urls) { %w[url1 url2] }

      it "gets each of the urls" do
        expect(request_manager).to receive(:get).once.with("url1", anything)
        expect(request_manager).to receive(:get).once.with("url2", anything)
        load_tester.run(urls)
      end

      it "reports stats on the responses" do
        expect(load_tester).to receive(:report_stats)
        load_tester.run(urls)
      end

      it "returns the stats" do
        allow(load_tester).to receive(:report_stats).and_return("stats")
        expect(load_tester.run(urls)).to eq("stats")
      end
    end
  end
end
