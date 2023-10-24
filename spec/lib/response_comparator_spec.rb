# frozen_string_literal: true

require "faraday"

require "spec_helper"
require "response_comparator"

RSpec.describe ResponseComparator do
  subject(:comparator) { described_class.new(primary_response, secondary_response, full_comparison_pct) }

  let(:full_comparison_pct) { 0 }
  let(:primary_response_body) { "primary response body" }
  let(:secondary_response_body) { "secondary response body" }

  let(:primary_response) do
    instance_double(Faraday::Response, {
      body: primary_response_body,
      status: 200,
      headers: {
        "X-Response-Time" => 123.456,
        "Content-type" => "text/plain",
      },
    })
  end
  let(:secondary_response) do
    instance_double(Faraday::Response, {
      body: secondary_response_body,
      status: 200,
      headers: {
        "X-Response-Time" => 456.789,
        "Content-type" => "text/plain",
      },
    })
  end

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
        let(:result) { comparator.response_stats(response) }

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
      let(:string1) { "a string of length 21" }
      let(:return_value) { comparator.first_difference(string1, string2) }

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
          let(:string2) { "a string!of length 21" }

          describe "the return value" do
            it "has :context set to the 5 characters either side of the first difference, from each string" do
              expect(return_value[:context]).to eq(["tring of le", "tring!of le"])
            end
          end
        end

        context "and the difference is more than 5 characters from the start and less than 5 characters from the end" do
          let(:string2) { "a string of length!21" }

          describe "the return value" do
            it "has :context set to the 5 characters before the first difference, and only up to the end of each string" do
              expect(return_value[:context]).to eq(["ength 21", "ength!21"])
            end
          end
        end

        context "and the difference is less than 5 characters from the start and more than 5 characters from the end" do
          let(:string2) { "a string of length!21" }

          describe "the return value" do
            it "has :context set to the available characters before the first difference, and the 5 characters after each string" do
              expect(return_value[:context]).to eq(["ength 21", "ength!21"])
            end
          end
        end

        context "and the difference is after the end of string1" do
          let(:string2) { "#{string1}!" }

          describe "the return value" do
            it "has :position set to the position of the first difference" do
              expect(return_value[:position]).to eq(21)
            end

            it "has :context set to the 5 characters either side of the first difference, from each string" do
              expect(return_value[:context]).to eq(["th 21", "th 21!"])
            end
          end
        end

        context "and the difference is after the end of string2" do
          let(:string1) { "#{string2}!" }

          describe "the return value" do
            it "has :position set to the position of the first difference" do
              expect(return_value[:position]).to eq(18)
            end

            it "has :context set to the 5 characters either side of the first difference, from each string" do
              expect(return_value[:context]).to eq(["tring!", "tring"])
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
        expect(comparator.different_keys(string1, string2)).to eq(%w[b c])
      end

      context "when the only difference is in :updated_at" do
        let(:string1) { { a: "a", b: "b", updated_at: "2023-06-01T08:00:01Z" }.to_json }

        context "and the difference is less than max_updated_at_difference" do
          let(:string2) { { a: "a", b: "b", updated_at: "2023-06-01T08:00:02Z" }.to_json }

          it "returns an empty array" do
            expect(comparator.different_keys(string1, string2)).to be_empty
          end
        end

        context "and the difference is more than max_updated_at_difference" do
          let(:string2) { { a: "a", b: "b", updated_at: "2023-06-01T08:00:11Z" }.to_json }

          it "returns an array containing updated_at" do
            expect(comparator.different_keys(string1, string2)).to eq(%w[updated_at])
          end
        end
      end

      context "when there is a difference in updated_at and another key" do
        let(:string1) { { a: "a", b: "b", updated_at: "2023-06-01T08:00:01Z" }.to_json }
        let(:string2) { { a: "a", b: "different b", updated_at: "2023-06-01T08:00:05Z" }.to_json }

        it "returns an array containing updated_at and the other different field" do
          expect(comparator.different_keys(string1, string2)).to eq(%w[b updated_at])
        end
      end
    end

    context "when given two strings that are not both JSON" do
      let(:string1) { "not json" }
      let(:string2) { "not json either" }

      it "does not error" do
        expect { comparator.different_keys(string1, string2) }.not_to raise_error
      end

      it "returns N/A" do
        expect(comparator.different_keys(string1, string2)).to eq("N/A")
      end
    end
  end

  describe ".compare" do
    describe "the return value" do
      let(:return_value) { comparator.compare }

      it "is a Hash" do
        expect(return_value).to be_a(Hash)
      end

      it "has a primary_response key" do
        expect(return_value.keys).to include(:primary_response)
      end

      describe "the primary_response key" do
        let(:primary_response_key) { return_value[:primary_response] }

        it "is set to the response_stats for the primary_response" do
          expect(primary_response_key).to eq({ body_size: 21, status: 200, time: 123.456 })
        end
      end

      describe "the secondary_response key" do
        let(:secondary_response_key) { return_value[:secondary_response] }

        it "is set to the response_stats for the secondary_response" do
          expect(secondary_response_key).to eq({ body_size: 23, status: 200, time: 456.789 })
        end

        context "when the secondary_response is nil" do
          let(:secondary_response) { nil }

          it "is nil" do
            expect(secondary_response_key).to be_nil
          end
        end
      end

      context "when it's not a full_comparison" do
        let(:full_comparison_pct) { 0 }

        describe "the different_keys key" do
          it "is not present" do
            expect(return_value.keys).not_to include(:different_keys)
          end
        end

        describe "the first_difference key" do
          it "is not present" do
            expect(return_value.keys).not_to include(:first_difference)
          end
        end
      end

      context "when it is a full_comparison" do
        let(:full_comparison_pct) { 100 }

        let(:primary_response_body) { { a: "a", b: "b", c: "c" }.to_json }
        let(:secondary_response_body) { { a: "a", b: "b", z: "z" }.to_json }

        describe "the different_keys key" do
          it "is set to the names of keys which differ" do
            expect(return_value[:different_keys]).to eq(%w[c z])
          end
        end

        describe "the first_difference key" do
          let(:first_difference) { "first diff" }

          it "is a Hash" do
            expect(return_value[:first_difference]).to be_a(Hash)
          end

          describe "position key" do
            it "is set to the index of the first difference" do
              expect(return_value[:first_difference][:position]).to eq(18)
            end
          end

          describe "context key" do
            it "has 5 characters each side of the position" do
              expect(return_value[:first_difference][:context]).to eq(["\"b\",\"c\":\"c\"", "\"b\",\"z\":\"z\""])
            end
          end
        end

        context "but the secondary_response is nil" do
          let(:secondary_response) { nil }

          describe "the different_keys key" do
            it "is not present" do
              expect(return_value.keys).not_to include(:different_keys)
            end
          end

          describe "the first_difference key" do
            it "is not present" do
              expect(return_value.keys).not_to include(:first_difference)
            end
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

  describe ".full_comparison?" do
    let(:comparison) { {} }

    context "when the random number from 0-99 is less than the given full_pct" do
      before do
        allow(Random).to receive(:rand).with(100).and_return(5)
      end

      it "returns true" do
        expect(comparator.full_comparison?(comparison, 10)).to eq(true)
      end
    end

    context "when the random number from 0-99 is greater than the given full_pct" do
      before do
        allow(Random).to receive(:rand).with(100).and_return(25)
      end

      it "returns false" do
        expect(comparator.full_comparison?(comparison, 10)).to eq(false)
      end
    end

    it "adds :r and :sample_percent keys to the given comparison" do
      allow(Random).to receive(:rand).with(100).and_return(26)
      obj = {}
      comparator.full_comparison?(obj, 10)
      expect(obj[:r]).to eq(26)
      expect(obj[:sample_percent]).to eq(10)
    end
  end

  describe ".timestamps_close_enough" do
    context "when given two strings which are valid iso8601 timestamps" do
      let(:string1) { "2023-08-24T12:10:26Z" }
      let(:string2) { "2023-08-24T12:10:28Z" }

      context "and they differ by less than max_diff seconds" do
        let(:max_diff) { 3 }

        it "returns true" do
          expect(comparator.timestamps_close_enough(string1, string2, max_diff)).to eq(true)
        end
      end

      context "and they differ by more than max_diff seconds" do
        let(:max_diff) { 1 }

        it "returns false" do
          expect(comparator.timestamps_close_enough(string1, string2, max_diff)).to eq(false)
        end
      end
    end

    context "when given two strings which are not both valid iso8601 timestamps" do
      let(:string1) { "2023-08-24T12:10:26Z" }
      let(:string2) { "2023-08-24 66:88:99" }

      it "returns false" do
        expect(comparator.timestamps_close_enough(string1, string2, 2)).to eq(false)
      end
    end
  end

  describe ".integers_close_enough" do
    context "when given two valid integers" do
      let(:int1) { 123 }
      let(:int2) { 125 }

      context "and they differ by less than max_diff seconds" do
        let(:max_diff) { 3 }

        it "returns true" do
          expect(comparator.integers_close_enough(int1, int2, max_diff)).to eq(true)
        end
      end

      context "and they differ by more than max_diff seconds" do
        let(:max_diff) { 1 }

        it "returns false" do
          expect(comparator.integers_close_enough(int1, int2, max_diff)).to eq(false)
        end
      end
    end

    context "when given two values which are not both valid integers" do
      let(:int1) { nil }
      let(:int2) { "a lizard" }

      it "does not raise an error" do
        expect { comparator.integers_close_enough(int1, int2, 2) }.not_to raise_error
      end

      it "returns false" do
        expect(comparator.integers_close_enough(int1, int2, 2)).to eq(false)
      end
    end
  end
end
