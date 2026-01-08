require 'rails_helper'

module BlacklightCornellRequests
  RSpec.describe MannSpecialDeliveryLinkBuilder do
    let(:work) do
      double(
        author: 'Jane Doe',
        title: 'Test Title',
        call_number: 'QA123'
      )
    end

    let(:patron_record_base) do
      {
        'personal' => {
          'firstName' => 'Test',
          'lastName' => 'User',
          'phone' => '555-1234',
          'addresses' => []
        },
        'customFields' => {
          'department' => 'History'
        }
      }
    end

    let(:patron) { double(get_folio_record: patron_record) }

    context 'with full patron address' do
      let(:patron_record) do
        record = patron_record_base.dup
        record['personal']['addresses'] = [
          {
            'primaryAddress' => true,
            'addressLine1' => '123 Main St',
            'addressLine2' => 'Apt 4',
            'city' => 'Ithaca',
            'region' => 'NY',
            'postalCode' => '14853'
          }
        ]
        record
      end

      it 'includes all fields in the link' do
        link = described_class.build(work, patron)
        expect(link).to include(CGI.escape('Jane Doe'))
        expect(link).to include(CGI.escape('Test Title'))
        expect(link).to include(CGI.escape('QA123'))
        expect(link).to include('123 Main St')
        expect(link).to include('Apt 4')
        expect(link).to include('Ithaca')
        expect(link).to include('NY')
        expect(link).to include('14853')
        expect(link).to include(CGI.escape('Test User'))
        expect(link).to include(CGI.escape('555-1234'))
        expect(link).to include(CGI.escape('History'))
      end
    end

    context 'with no primary address' do
      let(:patron_record) do
        record = patron_record_base.dup
        record['personal']['addresses'] = [
          {
            'primaryAddress' => false,
            'addressLine1' => '456 Main St',
            'city' => 'Ithaca',
            'region' => 'NY',
            'postalCode' => '14850'
          }
        ]
        record
      end

      it 'uses the first address' do
        link = described_class.build(work, patron)
        expect(link).to include(CGI.escape('3859679='))
        expect(link).to include(CGI.escape('456 Main St'))
        expect(link).to include(CGI.escape('Ithaca'))
        expect(link).to include(CGI.escape('NY'))
        expect(link).to include(CGI.escape('14850'))
        expect(link).to include(CGI.escape('Test User'))
      end 
    end

    context 'without address' do
      let(:patron_record) do
        record = patron_record_base.dup
        record['personal']['addresses'] = []
        record
      end

      it 'omits the address field' do
        link = described_class.build(work, patron)
        expect(link).not_to include('3859679=')
        expect(link).to include(CGI.escape('Test User'))
      end
    end

    context 'with missing patron_record' do
      let(:patron) { double(get_folio_record: nil) }

      it 'returns a link with only work fields' do
        link = described_class.build(work, patron)
        expect(link).to include(CGI.escape('Jane Doe'))
        expect(link).to include(CGI.escape('Test Title'))
        expect(link).to include(CGI.escape('QA123'))
        expect(link).not_to include('Test User')
      end
    end
  end
end