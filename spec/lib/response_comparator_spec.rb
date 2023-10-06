# frozen_string_literal: true

require "faraday"

require "spec_helper"
require "faraday"
require "response_comparator"

RSpec.describe ResponseComparator do
  describe ".response_stats" do
    context "when given a response" do
      let(:response) do
        instance_double(Faraday::Response,
                        {
                          status: 418,
                          body: "a 16-char string",
                          headers: {
                            "X-Response-Time" => 123.456,
                            "Content-type" => "text/plain",
                          },
                        })
      end

      describe "the returned value" do
        let(:result) { described_class.response_stats(response) }

        it "is a Hash" do
          expect(result).to be_a(Hash)
        end

        it "has :status set to the response status" do
          expect(result[:status]).to eq(418)
        end

        it "has :body_size set to the length of the response body" do
          expect(result[:body_size]).to eq(16)
        end

        it "has :time set to the X-Response-Time header from the response" do
          expect(result[:time]).to eq(123.456)
        end
      end
    end
  end

  describe ".first_difference" do
    context "when given two strings" do
      let(:string1) { "a string of length 20" }
      let(:return_value) { described_class.first_difference(string1, string2) }

      context "with the same value" do
        let(:string2) { string1.dup }

        it "returns {}" do
          expect(return_value).to eq({})
        end
      end

      context "with a difference" do
        let(:string2) { "a different string" }

        describe "the return value" do
          it "has :position set to the position of the first difference" do
            expect(return_value[:position]).to eq(2)
          end
        end

        context "and the difference is more than 5 characters from the start and more than 5 characters from the end" do
          let(:string2) { "a string!of length 20" }

          describe "the return value" do
            it "has :context set to the 5 characters either side of the first difference, from each string" do
              expect(return_value[:context]).to eq(["tring of le", "tring!of le"])
            end
          end
        end

        context "and the difference is more than 5 characters from the start and less than 5 characters from the end" do
          let(:string2) { "a string of length!20" }

          describe "the return value" do
            it "has :context set to the 5 characters before the first difference, and only up to the end of each string" do
              expect(return_value[:context]).to eq(["ength 20", "ength!20"])
            end
          end
        end

        context "and the difference is less than 5 characters from the start and more than 5 characters from the end" do
          let(:string2) { "a string of length!20" }

          describe "the return value" do
            it "has :context set to the available characters before the first difference, and the 5 characters after each string" do
              expect(return_value[:context]).to eq(["ength 20", "ength!20"])
            end
          end
        end
      end
    end
  end

  describe ".different_keys" do
    context "when given two strings that are both JSON" do
      let(:string1) { { a: "a", b: "b", c: %w[c1 c2] }.to_json }
      let(:string2) { { a: "a", b: "different b", c: ["c1", "different c2"] }.to_json }

      it "returns an array of the keys with different values" do
        expect(described_class.different_keys(string1, string2)).to eq(%w[b c])
      end

      context "when the only difference is in :updated_at" do
        let(:string1) { { a: "a", b: "b", updated_at: "2023-06-01T08:00:01Z" }.to_json }

        context "and the difference is less than max_updated_at_difference" do
          let(:string2) { { a: "a", b: "b", updated_at: "2023-06-01T08:00:02Z" }.to_json }

          it "returns an empty array" do
            expect(described_class.different_keys(string1, string2)).to be_empty
          end
        end

        context "and the difference is more than max_updated_at_difference" do
          let(:string2) { { a: "a", b: "b", updated_at: "2023-06-01T08:00:03Z" }.to_json }

          before do
            allow(described_class).to receive(:max_updated_at_difference).and_return(1)
          end

          it "returns an array containing updated_at" do
            expect(described_class.different_keys(string1, string2)).to eq(%w[updated_at])
          end
        end
      end

      context "when there is a difference in updated_at and another key" do
        let(:string1) { { a: "a", b: "b", updated_at: "2023-06-01T08:00:01Z" }.to_json }
        let(:string2) { { a: "a", b: "different b", updated_at: "2023-06-01T08:00:05Z" }.to_json }

        it "returns an array containing updated_at and the other different field" do
          expect(described_class.different_keys(string1, string2)).to eq(%w[b updated_at])
        end
      end
    end

    context "when given two strings that are not both JSON" do
      let(:string1) { "not json" }
      let(:string2) { "not json either" }

      it "does not error" do
        expect { described_class.different_keys(string1, string2) }.not_to raise_error
      end

      it "returns N/A" do
        expect(described_class.different_keys(string1, string2)).to eq("N/A")
      end
    end
  end

  describe ".compare" do
    context "when given a primary_response and a secondary_response" do
      let(:primary_response) do
        instance_double(Faraday::Response, {
          body: "primary response body",
        })
      end
      let(:secondary_response) do
        instance_double(Faraday::Response, {
          body: "secondary response body",
        })
      end

      describe "the return value" do
        let(:return_value) { described_class.compare(primary_response, secondary_response) }

        before do
          allow(described_class).to receive(:response_stats).with(primary_response).and_return("mock primary response stats")
          allow(described_class).to receive(:response_stats).with(secondary_response).and_return("mock secondary response stats")
          allow(described_class).to receive(:different_keys).and_return([])
          allow(described_class).to receive(:first_difference).and_return("N/A")
        end

        it "is a Hash" do
          expect(return_value).to be_a(Hash)
        end

        it "has a primary_response key" do
          expect(return_value.keys).to include(:primary_response)
        end

        describe "the primary_response key" do
          let(:primary_response_key) { return_value[:primary_response] }

          it "is set to the response_stats for the primary_response" do
            expect(primary_response_key).to eq("mock primary response stats")
          end
        end

        describe "the secondary_response key" do
          let(:secondary_response_key) { return_value[:secondary_response] }

          it "is set to the response_stats for the secondary_response" do
            expect(secondary_response_key).to eq("mock secondary response stats")
          end
        end

        context "when given a type of :quick" do
          let(:return_value) { described_class.compare(primary_response, secondary_response, :quick) }

          it "does not call different_keys" do
            expect(described_class).not_to receive(:different_keys)
            return_value
          end

          describe "the different_keys key" do
            it "is 'N/A'" do
              expect(return_value[:different_keys]).to eq("N/A")
            end
          end

          it "does not call first_difference" do
            expect(described_class).not_to receive(:first_difference)
            return_value
          end

          describe "the first_difference key" do
            it "is 'N/A'" do
              expect(return_value[:first_difference]).to eq("N/A")
            end
          end
        end

        context "when given a type of :full" do
          let(:return_value) { described_class.compare(primary_response, secondary_response, :full) }

          it "calls different_keys" do
            expect(described_class).to receive(:different_keys)
            return_value
          end

          describe "the different_keys key" do
            let(:different_keys) { %w[key1 key2] }

            before do
              allow(described_class).to receive(:different_keys).and_return(different_keys)
            end

            it "is set to the return value of different_keys" do
              expect(return_value[:different_keys]).to eq(different_keys)
            end
          end

          it "calls first_difference" do
            expect(described_class).to receive(:first_difference)
            return_value
          end

          describe "the first_difference key" do
            let(:first_difference) { "first diff" }

            before do
              allow(described_class).to receive(:first_difference).and_return(first_difference)
            end

            it "is set to the return value of first_difference" do
              expect(return_value[:first_difference]).to eq(first_difference)
            end
          end
        end

        describe "the response_comparison_seconds key" do
          it "is a non-zero float" do
            expect(return_value[:comparison_time_seconds]).to be > 0.00
          end
        end
      end
    end
  end

  describe ".timestamps_close_enough" do
    context "when given two strings which are valid iso8601 timestamps" do
      let(:string1) { "2023-08-24T12:10:26Z" }
      let(:string2) { "2023-08-24T12:10:28Z" }

      context "and they differ by less than max_diff seconds" do
        let(:max_diff) { 3 }

        it "returns true" do
          expect(described_class.timestamps_close_enough(string1, string2, max_diff)).to eq(true)
        end
      end

      context "and they differ by more than max_diff seconds" do
        let(:max_diff) { 1 }

        it "returns false" do
          expect(described_class.timestamps_close_enough(string1, string2, max_diff)).to eq(false)
        end
      end
    end

    context "when given two strings which are not both valid iso8601 timestamps" do
      let(:string1) { "2023-08-24T12:10:26Z" }
      let(:string2) { "2023-08-24 66:88:99" }

      it "returns false" do
        expect(described_class.timestamps_close_enough(string1, string2, 2)).to eq(false)
      end
    end
  end
end
