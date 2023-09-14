require "spec_helper"
require "comparison_logger"

RSpec.describe ComparisonLogger do
  subject { described_class.new(request: mock_request, comparison: comparison) }

  let(:request_method) { "GET" }
  let(:path) { "/" }
  let(:query_string) { "foo=bar" }

  let(:mock_request) { 
    instance_double(Rack::Request, method: request_method, path: path, query_string: query_string)
  }
  
  let(:status_1) { 200 }
  let(:status_2) { 200 }
  let(:body_size_1) { 12345 }
  let(:body_size_2) { 12345 }

  let(:comparison) { 
    {
      different_keys: different_keys,
      stats: {
        primary_response: {
          body_size: body_size_1,
          status: status_1,
        },
        secondary_response: {
          body_size: body_size_2,
          status: status_2,
        },
      }
    }
  }
  
  describe "#level" do
    context "when the comparison has different_keys: 'N/A'" do
      let(:different_keys) { "N/A" }

      context "and the statusses are the same" do
        let(:status_2) { 200 }

        context "and the body sizes are the same" do
          let(:body_size_2) { 12345 }

          it "returns :info" do
            expect(subject.level).to eq(:info)
          end
        end

        context "and the body sizes are not the same" do
          let(:body_size_2) { 67890 }

          it "returns :warn" do
            expect(subject.level).to eq(:warn)
          end
        end
      end

      context "and the statusses are not the same" do
        let(:status_2) { 504 }

        it "returns :warn" do
          expect(subject.level).to eq(:warn)
        end
      end
    end
  end
end