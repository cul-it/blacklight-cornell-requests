require 'spec_helper'
#require 'blacklight_cornell_requests/request'
require 'blacklight_cornell_requests/borrow_direct'

describe BlacklightCornellRequests::Request do

  describe "Primary functions" do

    describe "get_guest_delivery_options" do

      let (:request)  { FactoryGirl.create(:request) }

      context "noncirculating item" do
        it "returns an empty set for 'nocirc' items" do
          item = { :item_type_id => 9 }
          options = request.get_guest_delivery_options(item)
          expect(options).to eq([])
        end
        it "return an empty set for other noncirculating items" do
          item = { :item_type_id => 2, :status => 1 }
          request.stub(:noncirculating?).and_return(true)
          options = request.get_guest_delivery_options(item)
          expect(options).to eq([])
        end
      end  # context noncirculating item

      context "regular loan item" do
        it "returns L2L if item is not charged" do
          item = { :item_type_id => 2, :status => 1 }
          options = request.get_guest_delivery_options(item)
          expect(options[0][:service]).to eq('l2l')
          expect(options.count).to eq(1)
        end
        it "returns HOLD if item is charged" do
          item = { :item_type_id => 2, :status => 2 }
          options = request.get_guest_delivery_options(item)
          expect(options[0][:service]).to eq('hold')
          expect(options.count).to eq(1)
        end
        it "returns an empty set if the item is missing" do
          item = { :item_type_id => 2, :status => 12 }
          options = request.get_guest_delivery_options(item)
          expect(options).to eq([])    
        end
        it "returns an empty set if the item is lost" do
          item = { :item_type_id => 2, :status => 26 }
          options = request.get_guest_delivery_options(item)
          expect(options).to eq([])     
        end
      end # context regular loan item

      context "day loan item" do 
        it "returns L2L if item is not charged" do
          item = { :item_type_id => 5, :status => 1 }
          options = request.get_guest_delivery_options(item)
          expect(options[0][:service]).to eq('l2l')
          expect(options.count).to eq(1)        
        end
        it "returns HOLD if item is charged" do
          item = { :item_type_id => 5, :status => 2 }
          options = request.get_guest_delivery_options(item)
          expect(options[0][:service]).to eq('hold')
          expect(options.count).to eq(1)
        end
        it "returns an empty set if the item is missing" do
          item = { :item_type_id => 5, :status => 12 }
          options = request.get_guest_delivery_options(item)
          expect(options).to eq([])  
        end
        it "returns an empty set if the item is lost" do
          item = { :item_type_id => 5, :status => 26 }
          options = request.get_guest_delivery_options(item)
          expect(options).to eq([]) 
        end
      end # context day loan item

      context "minute loan item" do 
        it "returns ask at circulation if item is not charged" do
          item = { :item_type_id => 12, :status => 1 }
          options = request.get_guest_delivery_options(item)
          expect(options[0][:service]).to eq('circ')
          expect(options.count).to eq(1) 
        end
        it "returns ask at circulation if item is charged" do
          item = { :item_type_id => 12, :status => 2 }
          options = request.get_guest_delivery_options(item)
          expect(options[0][:service]).to eq('circ')
          expect(options.count).to eq(1)        
        end
        it "returns an empty set if the item is missing" do
          item = { :item_type_id => 12, :status => 12 }
          options = request.get_guest_delivery_options(item)
          expect(options).to eq([])          
        end
        it "returns an empty set if the item is lost" do
          item = { :item_type_id => 12, :status => 26 }
          options = request.get_guest_delivery_options(item)
          expect(options).to eq([])          
        end
      end # context day loan item

    end #describe get guest delivery options

  end #describe primary functions

end