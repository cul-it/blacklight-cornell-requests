require 'spec_helper'
require 'blacklight_cornell_requests/request'
require 'blacklight_cornell_requests/borrow_direct'
 
 describe BlacklightCornellRequests::Request do

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

	context "Main request function" do

		# it "returns the request options array, service, and Solr document" do
		# 	req = FactoryGirl.build(:request, bibid: nil)
		# 	req.magic_request
			
		# 	req.request_options.class.name.should == "Array"
		# 	req.service.should == "ask"
		# 	req.document.should == nil
		# end

		# context "Patron is Cornell-affiliated" do

		# 	let(:req) { FactoryGirl.build(:request, bibid: nil) }
		# 	before(:all) { req.netid = 'sk274' }

		# 	context "Loan type is regular" do

		# 		context "item status is 'not charged'" do

		# 			before(:all) {
		# 				req.bibid = 7924013
		# 				VCR.use_cassette 'holdings/cornell_regular_notcharged' do
		# 					req.get_holdings('retrieve_detail_raw')
		# 				end		
		# 				req.magic_request
		# 			}

		# 			it "sets service to 'l2l'" do
		# 				req.service.should == 'l2l'
		# 			end

		# 			it "sets request options to 'l2l'" do
		# 				req.request_options[0][:service].should == 'l2l'
		# 				req.request_options.size.should == 1
		# 			end

		# 		end

		# 		context "item status is 'charged'" do

		# 			before(:all) { 
		# 				req.bibid = 3955095
		# 				VCR.use_cassette 'holdings/cornell_regular_charged' do
		# 					req.get_holdings('retrieve_detail_raw')
		# 				end					
		# 			}

		# 			context "available through Borrow Direct" do

		# 				before(:all) {
		# 					req.stub(:borrowDirect_available?).and_return(true) 
		# 					req.magic_request	
		# 				}

		# 				it "sets service to 'bd'" do
		# 					req.service.should == 'bd'
		# 				end

		# 				it "sets request options to 'bd, recall, ill, hold'" do
		# 					req.request_options[0][:service].should == 'bd'
		# 					req.request_options.size.should == 4
		# 				end

		# 			end

		# 			context "not available through Borrow Direct" do

		# 				before(:all) { 
		# 					req.stub(:borrowDirect_available?).and_return(false) 
		# 					req.magic_request
		# 				}

		# 				it "sets service to 'ill'" do
		# 					req.service.should == 'ill'
		# 				end

		# 				it "sets request options to 'ill, recall, hold'" do
		# 					req.request_options[0][:service].should == 'ill'
		# 					req.request_options.size.should == 3
		# 				end

		# 			end

		# 		end

		# 		context "Item status is 'requested'" do

		# 			before(:all) { 
		# 				req.bibid = 6370407
		# 				VCR.use_cassette 'holdings/cornell_regular_requested' do
		# 					req.get_holdings('retrieve_detail_raw')
		# 				end					
		# 			}

		# 			context "available through Borrow Direct" do

		# 				before(:all) {
		# 					req.stub(:borrowDirect_available?).and_return(true) 
		# 					req.magic_request	
		# 				}

		# 				it "sets service to 'bd'" do
		# 					req.service.should == 'bd'
		# 				end

		# 				it "sets request options to 'bd, recall, ill, hold'" do
		# 					req.request_options[0][:service].should == 'bd'
		# 					req.request_options.size.should == 4
		# 				end

		# 			end

		# 			context "not available through Borrow Direct" do

		# 				before(:all) { 
		# 					req.stub(:borrowDirect_available?).and_return(false) 
		# 					req.magic_request
		# 				}

		# 				it "sets service to 'ill'" do
		# 					req.service.should == 'ill'
		# 				end

		# 				it "sets request options to 'ill, recall, hold'" do
		# 					req.request_options[0][:service].should == 'ill'
		# 					req.request_options.size.should == 3
		# 				end

		# 			end

		# 		end

		# 	end

		# 	context "Loan type is day" do
		# 	end

		# 	context "Loan type is minute" do
		# 	end

		# end

		# context "Patron is a guest" do
		# end

		context "Testing delivery_options functions" do

			let(:req) { FactoryGirl.build(:request, bibid: nil) }
			before(:each) { 
				req.stub(:get_cornell_delivery_options).and_return(1)
				req.stub(:get_guest_delivery_options).and_return(2)
			}

			it "should use get_cornell_delivery_options if patron is Cornell" do 
				req.netid = 'mjc12' 
				req.get_delivery_options(nil).should == 1
			end

			it "should use get_guest_delivery_options if patron is guest" do 
				req.netid = 'gid-silterrae'
				req.get_delivery_options(nil).should == 2
			end

			it "should use get_guest_delivery_options if patron is null" do 
				req.netid = ''
				req.get_delivery_options(nil).should == 2
			end

		end

	end

	context "Working with holdings data" do

		context "retrieving holdings data for its bib id" do

			it "returns nil if no bibid is passed in" do
				request = FactoryGirl.build(:request, bibid: nil)
				result = request.get_holdings
				result.should == nil
			end

			it "returns nil for an invalid bibid" do
				request = FactoryGirl.build(:request, bibid: 500000000)
				VCR.use_cassette 'holdings/invalid_bibid' do
					result = request.get_holdings
					result[request.bibid.to_s]['condensed_holdings_full'].should == []
				end
			end

			it "returns a condensed holdings record if type = 'retrieve'" do
				request = FactoryGirl.build(:request, bibid: 6665264)
				VCR.use_cassette 'holdings/condensed' do
					result = request.get_holdings 'retrieve' 
					result[request.bibid.to_s]['condensed_holdings_full'].should_not == []
				end
			end

			it "returns a condensed holdings record if no type is specified" do
				request = FactoryGirl.build(:request, bibid: 6665264)
				VCR.use_cassette 'holdings/condensed' do
					result = request.get_holdings
					result[request.bibid.to_s]['condensed_holdings_full'].empty?.should_not == true
				end
			end

			it "returns a verbose holdings record if type = 'retrieve_detail_raw" do
				request = FactoryGirl.build(:request, bibid: 6665264)
				VCR.use_cassette 'holdings/detail_raw' do
					result = request.get_holdings 'retrieve_detail_raw' 
					result[request.bibid.to_s]['records'].empty?.should_not == true
				end
			end

		end

		context "retrieving item types" do

			describe "get_item_type" do

				let(:request) { FactoryGirl.create(:request) }
				let(:day_loan_types) {
					[1, 5, 6, 7, 8, 10, 11, 13, 14, 15, 17, 18, 19, 20, 21, 23, 24, 25, 28, 33]
				}
				let(:minute_loan_types) {
					[12, 16, 22, 26, 27, 29, 30, 31, 32, 34, 35, 36, 37]
				}
				let(:nocirc_loan_types) { [9] }

				it "returns 'day' for a day-type loan" do
					day_loan_types.each do |t|
						request.loan_type(t).should == 'day'
					end
				end

				it "returns 'minute' for a minute-type loan" do
					minute_loan_types.each do |t|
						request.loan_type(t).should == 'minute'
					end
				end

				it "returns 'nocirc' for a non-circulating item" do
					nocirc_loan_types.each do |t|
						request.loan_type(t).should == 'nocirc'
					end
				end

				it "returns 'regular' for a regular loan" do
					(1..37).each do |t|
						unless day_loan_types.include? t or minute_loan_types.include? t or nocirc_loan_types.include? t
							request.loan_type(t).should == 'regular'
						end
					end
				end

				it "returns 'regular' if the loan type isn't recognized" do # is this really what we want?
					request.loan_type(-100).should == 'regular'
				end

			end

		end

		context "Getting item status" do

			describe "get_item_status" do

				let(:rc) { FactoryGirl.create(:request) }

				it "returns 'Not Charged' if item status includes 'Not Charged'" do
					result = rc.item_status 'status is Not Charged in this case'
					result.should == 'Not Charged'
				end

				it "returns 'Charged' if item status includes a left-anchored 'Charged'" do
					result = rc.item_status 'status is Charged in this case'
					result.should_not == 'Charged'
				end

				it "returns 'Charged' if item status includes a left-anchored 'Charged'" do
					result = rc.item_status 'Charged in this case'
					result.should == 'Charged'
				end

				it "returns 'Charged' if item status includes 'Renewed'" do
					result = rc.item_status 'status is Renewed in this case'
					result.should == 'Charged'
				end

				it "returns 'Requested' if item status includes 'Requested'" do
					result = rc.item_status 'status is Requested in this case'
					result.should == 'Requested'
				end

				it "returns 'Missing' if item status includes 'Missing'" do
					result = rc.item_status 'status is Missing in this case'
					result.should == 'Missing'
				end

				it "returns 'Lost' if item status includes 'Lost'" do
					result = rc.item_status 'status is Lost in this case'
					result.should == 'Lost'
				end

				it "returns the passed parameter if the status isn't recognized" do
					result = rc.item_status 'status is Leaving on a Jet Plane in this case'
					result.should == 'status is Leaving on a Jet Plane in this case'
				end

			end
		end

		context "Getting delivery times" do

			describe "returns " do

				it "does stuff" do
				end

			end

		end

	end

 end

