require 'spec_helper'
require 'blacklight_cornell_requests/voyager_request'
require 'vcr'
require 'james_monkeys'

describe BlacklightCornellRequests::VoyagerRequest do
 VOYAGER_GET_HOLDS = "***REMOVED***/GetHoldingsService"
 VOYAGER_REQ_HOLDS = "***REMOVED***/SendPatronRequestService"
 MYACC_URL  = '***REMOVED***/MyAccountService'
  it "has a valid factory" do
    FactoryGirl.create(:request).should be_valid
  end

  it "is invalid without a bibid" do
    FactoryGirl.build(:request, bibid: nil).should_not be_valid
  end

  it "has a valid initializer" do
    request = BlacklightCornellRequests::Request.new(12345)
    FactoryGirl.build(:request, bibid: 12345).bibid.should == request.bibid
  end
  it "fills in patron data correctly" do 
    @bibid, @mfhdid , @itemid, @libraryid , @reqnna , @netid  = callslipper
    req =  BlacklightCornellRequests::VoyagerRequest.new(@bibid,{:request_url => VOYAGER_REQ_HOLDS})
    req.netid = @netid
    VCR.use_cassette("patron_data_#{@netid}") do
      req.patron(@netid)
    end
    expect( req.lastname).to eq('***REMOVED***') 
  end

  context "When making a hold request" do
  let(:req) {
    @bibid, @mfhdid , @itemid, @libraryid , @reqnna , @netid  =  requestholder
    areq =  BlacklightCornellRequests::VoyagerRequest.new(@bibid,{:request_url => VOYAGER_REQ_HOLDS})
    areq.netid = @netid
    VCR.use_cassette("patron_data_#{@netid}") do
      areq.patron(@netid)
    end
    areq
  }
  let(:adpreq) {
    @bibid, @mfhdid , @itemid, @libraryid , @reqnna , @xnetid  =  requestholder
    @xnetid = "xxxxadp78";
    areq =  BlacklightCornellRequests::VoyagerRequest.new(@bibid,{:request_url => VOYAGER_REQ_HOLDS})
    areq.netid = @xnetid
    VCR.use_cassette("patron_data_#{@xnetid}") do
      areq.patron(@xnetid)
    end
    areq
  }
  it "reports success properly" do 
    expect( req.lastname).to eq('***REMOVED***') 
    VCR.use_cassette("hold_response_data_#{@itemid}") do
      req.itemid = @itemid;
      req.mfhdid = @mfhdid;
      req.libraryid = @libraryid;
      req.reqnna = @reqnna
      req.place_hold_item!
    end
    expect( req.mtype).to eq 'success' 
  end
  it "reports error properly" do
    expect( req.lastname).to eq('***REMOVED***')
    VCR.use_cassette("hold_response_data_fail_#{@itemid}") do
      req.itemid = @itemid
      req.mfhdid = @mfhdid
      req.libraryid = @libraryid
      req.reqnna = @reqnna
      req.place_hold_item!
    end
    expect( req.mtype).to eq 'blocked'
  end

  it "reports error properly for an invalid item id" do 
    expect( req.lastname).to eq('***REMOVED***') 
    VCR.use_cassette("hold_response_data_fail_#{@itemid}") do
      req.itemid = @itemid + "xxx"
      req.mfhdid = @mfhdid
      req.libraryid = @libraryid
      req.reqnna = @reqnna
      req.place_hold_item!
    end
    expect( req.mtype).to eq 'blocked' 
  end

  it "reports error properly for an invalid user"   do
    @netid = "xxxxadp78";
    VCR.use_cassette("hold_response_data_fail_#{@netid}_#{@itemid}") do
      adpreq.itemid = @itemid
      adpreq.mfhdid = @mfhdid
      adpreq.libraryid = @libraryid
      adpreq.reqnna = @reqnna
      adpreq.place_hold_item!
    end
    expect( adpreq.mtype).to eq 'system' 
    expect( adpreq.bcode).to eq '' 
  end
  end

  context "When making a recall request" do
  let(:req) {
    @bibid, @mfhdid , @itemid, @libraryid , @reqnna , @netid  =  requestholder
    areq =  BlacklightCornellRequests::VoyagerRequest.new(@bibid,{:request_url => VOYAGER_REQ_HOLDS})
    areq.netid = @netid
    VCR.use_cassette("patron_data_#{@netid}") do
      areq.patron(@netid)
    end
    areq
  }
  let(:adpreq) {
    @bibid, @mfhdid , @itemid, @libraryid , @reqnna , @xnetid  =  requestholder
    @xnetid = "xxxxadp78";
    areq =  BlacklightCornellRequests::VoyagerRequest.new(@bibid,{:request_url => VOYAGER_REQ_HOLDS})
    areq.netid = @xnetid
    VCR.use_cassette("patron_data_#{@xnetid}") do
      areq.patron(@xnetid)
    end
    areq
  }

  it "reports success properly" do 
    expect( req.lastname).to eq('***REMOVED***') 
    VCR.use_cassette("recall_response_data_#{@itemid}") do
      req.itemid = @itemid
      req.mfhdid = @mfhdid
      req.libraryid = @libraryid
      req.reqnna = @reqnna
      req.place_recall_item!
    end
    expect( req.mtype).to eq 'success' 
  end

  it "reports error properly" do 
    expect( req.lastname).to eq('***REMOVED***') 
    VCR.use_cassette("recall_response_data_fail_#{@itemid}") do
      req.itemid = @itemid
      req.mfhdid = @mfhdid
      req.libraryid = @libraryid
      req.reqnna = @reqnna
      req.place_recall_item!
    end
    expect( req.mtype).to eq 'blocked' 
  end
  it "reports error properly for a invalid item id" do 
    expect( req.lastname).to eq('***REMOVED***') 
    VCR.use_cassette("recall_response_data_fail_#{@itemid}") do
      req.itemid = @itemid + "xxx"
      req.mfhdid = @mfhdid
      req.libraryid = @libraryid
      req.reqnna = @reqnna
      req.place_recall_item!
    end
    expect( req.mtype).to eq 'blocked' 
  end
  it "reports error properly for an invalid user"   do
    @netid = "xxxxadp78";
    adpreq.netid = @netid
    VCR.use_cassette("recall_response_data_fail_#{@netid}_#{@itemid}") do
      adpreq.itemid = @itemid
      adpreq.mfhdid = @mfhdid
      adpreq.libraryid = @libraryid
      adpreq.reqnna = @reqnna
      adpreq.place_recall_item!
    end
    expect( adpreq.mtype).to eq 'system' 
    expect( adpreq.bcode).to eq '' 
  end
  end

  context "When making a call slip request" do
  let(:req) {
    @bibid, @mfhdid , @itemid, @libraryid , @reqnna , @netid  =  callslipper
    areq =  BlacklightCornellRequests::VoyagerRequest.new(@bibid,{:request_url => VOYAGER_REQ_HOLDS})
    areq.netid = @netid
    VCR.use_cassette("patron_data_#{@netid}") do
      areq.patron(@netid)
    end
    areq
  }
  let(:adpreq) {
    @bibid, @mfhdid , @itemid, @libraryid , @reqnna , @xnetid  =  callslipper
    @xnetid = "xxxxadp78";
    areq =  BlacklightCornellRequests::VoyagerRequest.new(@bibid,{:request_url => VOYAGER_REQ_HOLDS})
    areq.netid = @xnetid
    VCR.use_cassette("patron_data_#{@xnetid}") do
      areq.patron(@xnetid)
    end
    areq
  }
  it "reports success properly"   do
    expect( req.lastname).to eq('***REMOVED***') 
    VCR.use_cassette("callslip_response_data_#{@itemid}") do
      req.itemid = @itemid
      req.mfhdid = @mfhdid
      req.libraryid = @libraryid
      req.reqnna = @reqnna
      req.place_callslip_item!
    end
    expect( req.mtype).to eq 'success' 
  end

  it "reports error properly"   do
    expect( req.lastname).to eq('***REMOVED***') 
    VCR.use_cassette("callslip_response_data_fail_#{@itemid}") do
      req.itemid = @itemid
      req.mfhdid = @mfhdid
      req.libraryid = @libraryid
      req.reqnna = @reqnna
      req.place_callslip_item!
    end
    expect( req.mtype).to eq 'blocked' 
  end
  it "reports error properly for an invalid item id" do 
    expect( req.lastname).to eq('***REMOVED***') 
    VCR.use_cassette("callslip_response_data_fail_#{@itemid}") do
      req.itemid = @itemid + "xxx"
      req.mfhdid = @mfhdid
      req.libraryid = @libraryid
      req.reqnna = @reqnna
      req.place_callslip_item!
    end
    expect( req.mtype).to eq 'blocked' 
  end

  it "reports error properly for an invalid user"   do
    @netid = "xxxxadp78";
    adpreq.netid = @netid
    VCR.use_cassette("callslip_response_data_fail_#{@netid}_#{@itemid}") do
      adpreq.itemid = @itemid
      adpreq.mfhdid = @mfhdid
      adpreq.libraryid = @libraryid
      adpreq.reqnna = @reqnna
      adpreq.place_callslip_item!
    end
    expect( adpreq.mtype).to eq 'system' 
    expect( adpreq.bcode).to eq '' 
  end
  end
  context "When a call slip request has been placed" do 
  it "appears in the user account data and can be cancelled" do
    @bibid, @mfhdid , @itemid, @libraryid , @reqnna , @netid  = callslipper
    req =  BlacklightCornellRequests::VoyagerRequest.new(@bibid,{:request_url => VOYAGER_REQ_HOLDS})
    req.netid = @netid
    VCR.use_cassette("patron_data_#{@netid}") do
      req.patron(@netid)
    end
    expect( req.lastname).to eq('***REMOVED***') 
    # Generate a callslip
    VCR.use_cassette("callslip_xy3response_data_to_cancel_#{@itemid}") do
      req.itemid = @itemid
      req.mfhdid = @mfhdid
      req.libraryid = @libraryid
      req.reqnna = @reqnna
      req.place_callslip_item!
    end
    expect(req.mtype).to eq 'success' 
    # Fetch the user account data to cancel the request 
    req2 =  BlacklightCornellRequests::VoyagerRequest.new(@bibid,{:request_url => MYACC_URL})
    req2.netid = @netid
    VCR.use_cassette("patron_data_#{@netid}") do
      req2.patron(@netid)
    end
    VCR.use_cassette("user_account_xy3response_to_cancel_data_#{@netid}") do
      req2.itemid = @itemid
      req2.mfhdid = @mfhdid
      req2.libraryid = @libraryid
      req2.reqnna = @reqnna
      req2.user_account
    end
    tocancel  = req2.requests.select{|h| h[:itemid] ==  req.itemid ? true : false  }
    expect(tocancel[0]).not_to be_nil, "There should be a matching item to cancel the hold on (bib,item)(b=#{@bibid},i=#{@itemid})"
    expect(tocancel[0]).not_to be_empty, "There should be a matching item to cancel the hold on (bib,item)(b=#{@bibid},i=#{@itemid})"
    expect(tocancel[0][:itemid]).to eq(@itemid)

    req.netid = @netid
    VCR.use_cassette("patron_data_#{@netid}") do
      req.patron(@netid)
    end
    expect( req.lastname).to eq('***REMOVED***') 
    VCR.use_cassette("callslip_cancel_xy3response_data_#{@netid}_#{@itemid}") do
      req.itemid = @itemid
      req.mfhdid = @mfhdid
      req.libraryid = @libraryid
      req.reqnna = @reqnna
      req.cancel_callslip_item!(tocancel[0][:holdrecallid])
    end
    expect(req.mtype).to eq 'success' 
    expect(req.bcode).to eq '0' 
  end
  end

 context "When a hold has been placed" do
 it "appears in the user account data and can be cancelled successfully" do
    @bibid, @mfhdid , @itemid, @libraryid , @reqnna , @netid  = requestholder
    req =  BlacklightCornellRequests::VoyagerRequest.new(@bibid,{:request_url => VOYAGER_REQ_HOLDS})
    req.netid = @netid
    VCR.use_cassette("patron_data_#{@netid}") do
      req.patron(@netid)
    end
    expect( req.lastname).to eq('***REMOVED***') 
    # Generate a hold 
    VCR.use_cassette("hold_xyresponse_data_#{@itemid}") do
      req.itemid = @itemid
      req.mfhdid = @mfhdid
      req.libraryid = @libraryid
      req.reqnna = @reqnna
      req.place_hold_item!
    end
    expect(req.mtype).to eq 'success' 
    # Fetch the user account data to cancel the request 
    req2 =  BlacklightCornellRequests::VoyagerRequest.new(@bibid,{:request_url => MYACC_URL})
    req2.netid = @netid
    VCR.use_cassette("patron_data_#{@netid}") do
      req2.patron(@netid)
    end
    VCR.use_cassette("hold_cancel_xyresponse_data_#{@netid}_#{@itemid}") do
      req2.itemid = @itemid
      req2.mfhdid = @mfhdid
      req2.libraryid = @libraryid
      req2.reqnna = @reqnna
      req2.user_account
    end
    # find the request for THIS item.
    tocancel  = req2.requests.select{|h| h[:itemid] ==  req.itemid ? true : false  }
    expect(tocancel[0]).not_to be_nil, "There should be a matching item to cancel the hold on (bib,item)(b=#{@bibid},i=#{@itemid})"
    expect(tocancel[0]).not_to be_empty, "There should be a matching item to cancel the hold on (bib,item)(b=#{@bibid},i=#{@itemid})"
    expect(tocancel[0][:itemid]).to eq(@itemid)
    # Fetch the user account data to cancel the request 
    #req3 =  BlacklightCornellRequests::VoyagerRequest.new(@bibid,{:request_url => VOYAGER_REQ_HOLDS})
    req.netid = @netid
    VCR.use_cassette("patron_data_#{@netid}") do
      req.patron(@netid)
    end
    expect( req.lastname).to eq('***REMOVED***') 
    VCR.use_cassette("hold_cancel_xy2response_data_#{@netid}_#{@itemid}") do
      req.itemid = @itemid
      req.mfhdid = @mfhdid
      req.libraryid = @libraryid
      req.reqnna = @reqnna
      req.cancel_hold_item!(tocancel[0][:holdrecallid])
    end
    expect(req.mtype).to eq 'success' 
    expect(req.bcode).to eq '0' 
  end
  end

 context "When a recall has been placed" do
 it "appears in the user account data and can be cancelled successfully" do
    @bibid, @mfhdid , @itemid, @libraryid , @reqnna , @netid  = requestholder
    req =  BlacklightCornellRequests::VoyagerRequest.new(@bibid,{:request_url => VOYAGER_REQ_HOLDS})
    req.netid = @netid
    VCR.use_cassette("patron_data_#{@netid}") do
      req.patron(@netid)
    end
    expect( req.lastname).to eq('***REMOVED***') 
    # Generate a hold 
    VCR.use_cassette("recall_xyresponse_data_#{@itemid}") do
      req.itemid = @itemid
      req.mfhdid = @mfhdid
      req.libraryid = @libraryid
      req.reqnna = @reqnna
      req.place_hold_item!
    end
    expect(req.mtype).to eq 'success' 
    # Fetch the user account data to cancel the request 
    req2 =  BlacklightCornellRequests::VoyagerRequest.new(@bibid,{:request_url => MYACC_URL})
    req2.netid = @netid
    VCR.use_cassette("patron_data_#{@netid}") do
      req2.patron(@netid)
    end
    VCR.use_cassette("recall_cancel_xyresponse_data_#{@netid}_#{@itemid}") do
      req2.itemid = @itemid
      req2.mfhdid = @mfhdid
      req2.libraryid = @libraryid
      req2.reqnna = @reqnna
      req2.user_account
    end
    # find the request for THIS item.
    tocancel  = req2.requests.select{|h| h[:itemid] ==  req.itemid ? true : false  }
    expect(tocancel[0]).not_to be_nil, "There should be a matching item to cancel the hold on (bib,item)(b=#{@bibid},i=#{@itemid})"
    expect(tocancel[0]).not_to be_empty, "There should be a matching item to cancel the hold on (bib,item)(b=#{@bibid},i=#{@itemid})"
    expect(tocancel[0][:itemid]).to eq(@itemid)
    # Fetch the user account data to cancel the request 
    #req3 =  BlacklightCornellRequests::VoyagerRequest.new(@bibid,{:request_url => VOYAGER_REQ_HOLDS})
    req.netid = @netid
    VCR.use_cassette("patron_data_#{@netid}") do
      req.patron(@netid)
    end
    expect( req.lastname).to eq('***REMOVED***') 
    VCR.use_cassette("recall_cancel_xy2response_data_#{@netid}_#{@itemid}") do
      req.itemid = @itemid
      req.mfhdid = @mfhdid
      req.libraryid = @libraryid
      req.reqnna = @reqnna
      req.cancel_hold_item!(tocancel[0][:holdrecallid])
    end
    expect(req.mtype).to eq 'success' 
    expect(req.bcode).to eq '0' 
  end
  end




private

  # bibid,mfhdid,itemid, libraryid,date,netid
  # you can put a call slip on this one
  def callslipper
  [
     "1001",
     "5195",
     "21352",
     "189",
     "2014-09-27",
     "***REMOVED***"]
  end

  # bibid,mfhdid,itemid, libraryid,date,netid
  # you can put a hold, or recall on this one
  # 3792882,4367276,5811637
  #
  def requestholder
   [ "6873904", "7315768", "8751586",
     "189", "2013-09-27", "***REMOVED***" ]
  end

  @odd = 0

  def many_requestholder
   @odd = @odd==1 ? 0 : 1
   @odd==0 ?  [ "6873904", "7315768", "8751586",
            "189", "2013-09-27", "***REMOVED***" ]
   :       [ "3792882", "4367276", "5811637",
           "189", "2013-09-27", "***REMOVED***" ]
  end


end
