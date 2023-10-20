require "sinatra/base"

require "spec_helper"
require "comparison_logger"

RSpec.describe ComparisonLogger do
  let(:primary_response_status) { 201 }
  let(:secondary_response_status) { 201 }
  let(:primary_response_body_size) { 22_222 }
  let(:secondary_response_body_size) { 22_222 }
  let(:different_keys) { nil }
  let(:first_difference) { nil }
  let(:primary_response_location) { nil }
  let(:secondary_response_location) { nil }

  let(:comparison) do
    {
      primary_response: {
        status: primary_response_status,
        body_size: primary_response_body_size,
        time: 0.001045556,
        location: primary_response_location,
      },
      secondary_response: {
        status: secondary_response_status,
        body_size: secondary_response_body_size,
        time: 0.000890302,
        location: secondary_response_location,
      },
      different_keys:,
      first_difference:,
      sample_percent: 0,
      r: 51,
      comparison_time_seconds: 1.9445e-05,
    }
  end
  let(:mock_env) { { "REQUEST_METHOD" => "GET", "QUERY_STRING" => "abc=123" } }
  let(:mock_request) { instance_double(Sinatra::Request, env: mock_env, path: "/api/content/") }

  describe ".log" do
    it "logs the generated line to STDOUT" do
      expect { described_class.log(comparison, mock_request) }.to output.to_stdout
    end
  end

  describe ".log_structure" do
    context "when given a comparison and a request" do
      describe "the result" do
        let(:result) { described_class.log_structure(comparison, mock_request) }

        it "is a Hash" do
          expect(result).to be_a(Hash)
        end

        it "has a timestamp" do
          expect(result[:timestamp]).not_to be_nil
        end

        it "has a level " do
          expect(result[:level]).not_to be_nil
        end

        it "has a method set to the request method" do
          expect(result[:method]).to eq("GET")
        end

        it "has path set to the request path" do
          expect(result[:path]).to eq("/api/content/")
        end

        it "has query_string set to the request query string" do
          expect(result[:query_string]).to eq("abc=123")
        end

        it "has stats set to the given comparison" do
          expect(result[:stats]).to eq(comparison)
        end
      end
    end
  end

  shared_examples_for described_class do
    let(:result) { described_class.log_level(comparison) }

    context "when the status of the two responses matches" do
      let(:primary_response_status) { 401 }
      let(:secondary_response_status) { 401 }

      context "when the body_size of the two responses matches" do
        let(:primary_response_body_size) { 12_345 }
        let(:secondary_response_body_size) { 12_345 }

        it "returns :info" do
          expect(result).to eq(:info)
        end
      end

      context "when the body_size of the two responses does not match" do
        let(:primary_response_body_size) { 12_345 }
        let(:secondary_response_body_size) { 23_456 }

        context "when the statuses are both 303" do
          let(:primary_response_status) { 303 }
          let(:secondary_response_status) { 303 }

          context "when the locations have the same path" do
            let(:primary_response_location) { "http://content-store-mongo-main/api/content/some-path" }
            let(:secondary_response_location) { "http://content-store-postgresql-branch/api/content/some-path" }

            it "returns :info" do
              expect(result).to eq(:info)
            end
          end

          context "when the locations do not have the same path" do
            let(:primary_response_location) { "http://content-store-mongo-main/api/content/some-path" }
            let(:secondary_response_location) { "http://content-store-mongo-main/api/content/some-other-path" }

            it "returns :warn" do
              expect(result).to eq(:warn)
            end
          end
        end

        context "when the statuses are not both 303" do
          it "returns :warn" do
            expect(result).to eq(:warn)
          end
        end
      end
    end

    context "when the status of the two responses does not match" do
      let(:primary_response_status) { 401 }
      let(:secondary_response_status) { 403 }

      it "returns :warn" do
        expect(result).to eq(:warn)
      end
    end
  end

  describe ".log_level" do
    context "when given a comparison" do
      context "with :different_keys set to nil" do
        let(:different_keys) { nil }

        it_behaves_like described_class
      end

      context "with :different_keys set to []" do
        let(:different_keys) { [] }

        it_behaves_like described_class
      end

      context "with :different_keys set to 'N/A'" do
        let(:different_keys) { "N/A" }

        it_behaves_like described_class
      end
    end
  end
end
