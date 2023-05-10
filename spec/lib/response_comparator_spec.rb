require "spec_helper"
require "response_comparator"

RSpec.describe ResponseComparator do
  describe ".response_stats" do
    context "given a response" do
      let(:response) do
        double(
          {
            status: 418,
            body: "a 16-char string",
            headers: {
              "X-Response-Time" => 123.456,
              "Content-type" => "text/plain",
            }
          }
        )
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
    context "given two strings" do
      let(:string1) { "a string of length 20" }
      let(:return_value) { described_class.first_difference(string1, string2) }

      context "that are both the same" do
        let(:string2) { string1.dup }

        it "returns {}" do
          expect(return_value).to eq({})
        end
      end

      context "that have a difference" do
        let(:string2) { "a different string" }

        describe "the return value" do
          it "has :position set to the position of the first difference" do
            expect(return_value[:position]).to eq(2)
          end
        end

        context "more than 5 characters from the start and more than 5 characters from the end" do
          let(:string2) { "a string!of length 20" }

          describe "the return value" do
            it "has :context set to the 5 characters either side of the first difference, from each string" do
              expect(return_value[:context]).to eq( ["tring of le", "tring!of le"] )
            end
          end
        end

        context "more than 5 characters from the start and less than 5 characters from the end" do
          let(:string2) { "a string of length!20" }

          describe "the return value" do
            it "has :context set to the 5 characters before the first difference, and only up to the end of each string" do
              expect(return_value[:context]).to eq( ["ength 20", "ength!20"] )
            end
          end
        end

        context "less than 5 characters from the start and more than 5 characters from the end" do
          let(:string2) { "a string of length!20" }

          describe "the return value" do
            it "has :context set to the available characters before the first difference, and the 5 characters after each string" do
              expect(return_value[:context]).to eq( ["ength 20", "ength!20"] )
            end
          end
        end
      end
    end
  end

  describe ".compare" do
    context "given a primary_response and a secondary_response" do
      let(:primary_response) do
        double({
          body: "primary response body",
        })
      end
      let(:secondary_response) do
        double({
          body: "secondary response body",
        })
      end

      describe "the return value" do
        let(:return_value) { described_class.compare(primary_response, secondary_response) }
        before do
          allow(described_class).to receive(:response_stats).with(primary_response).and_return("mock primary response stats")
          allow(described_class).to receive(:response_stats).with(secondary_response).and_return("mock secondary response stats")
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
      end
    end
  end

end