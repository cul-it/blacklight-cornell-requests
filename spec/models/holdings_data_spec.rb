require 'spec_helper'
require 'vcr'
require 'blacklight_cornell_requests'

describe BlacklightCornellRequests::HoldingsData do
  
  let (:document) { { :isbn_display => ['12345'],
                      :title_display => 'Test',
                      :author_display => ['Mr. Testcase']
                   } }
                   
  it "should return a new instance" do
    skip # have to update this to make the call to the holdings service
    # holdings = BlacklightCornellRequests::HoldingsData.new(1, document)
    # expect(holdings.bibid).to eq(1)
    # expect(holdings.document).to eq(document)
  end

end