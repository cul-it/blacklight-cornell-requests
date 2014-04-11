require 'spec_helper'
require 'blacklight_cornell_requests/request'
require 'blacklight_cornell_requests/borrow_direct'

describe BlacklightCornellRequests::Request do

  ############################### Basic class tests ##############################


  ################### Functions outside the main routine #######################
  describe "Secondary functions" do

    # make_voyager_request
    # create_ill_link

    describe "populate_document_values" do

      let (:request)  { FactoryGirl.create(:request) }
      let (:document) { { :isbn_display => ['12345'],
                          :title_display => 'Test',
                          :author_display => ['Mr. Testcase']
                       } }
      before (:each) do
        request.document = document
        request.populate_document_values
      end

      it "sets the request ISBN" do
        expect(request.isbn).to equal(document[:isbn_display])
      end

      it "sets the request title" do
        expect(request.ti).to equal(document[:title_display])
      end

      context 'when there is an author_display field' do
        it 'sets the request author' do
          expect(request.au).to eq(document[:author_display])
        end
      end

      context 'when there is an author_addl_display field' do
        it 'sets the request author' do
          request.document[:author_display] = nil
          request.document[:author_addl_display] = ['Mr. Testcase']
          request.populate_document_values
          expect(request.au).to eq(document[:author_addl_display])
        end
      end

      context 'when there is no author field' do
        it 'does not set the request author' do
          request.document[:author_display] = nil
          request.populate_document_values
          expect(request.au).to eq('')
        end
      end

    end

    # describe "find_month" do
    #   it "Returns the correct month number for month abbreviation" do
    #     names = %w[ Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec ]
    #     names.each do |n|
    #       r = FactoryGirl.build(:request)
    #       names.index(n).should == r.find_month(n) - 1
    #     end
    #   end
    # end





  end



end