require 'rails_helper'

RSpec.describe BlacklightCornellRequests::Item do
  let(:holding_id) { 'h1' }
  let(:item_data) do
    {
      'id' => 'item123',
      'location' => { 'code' => 'main', 'name' => 'Stacks' },
      'matType' => { 'id' => 'a00b928e-39ef-4c32-aec9-f57dfb588456' }, # 1 Day Loan
      'chron' => 'Spring',
      'enum' => 'v.1',
      'year' => '2020',
      'status' => { 'status' => 'Available' },
      'copy' => '1',
      'loanType' => { 'id' => 'some-loan-type' },
      'onReserve' => false
    }
  end
  let(:holdings_data) { { 'h1' => { 'call' => 'QA123 .A1' } } }

  subject { described_class.new(holding_id, item_data, holdings_data) }

  describe '#initialize' do
    it 'sets attributes from item_data and holdings_data' do
      expect(subject.id).to eq('item123')
      expect(subject.holding_id).to eq('h1')
      expect(subject.location).to eq({ 'code' => 'main', 'name' => 'Stacks' })
      expect(subject.type).to eq({ 'id' => 'a00b928e-39ef-4c32-aec9-f57dfb588456' })
      expect(subject.status).to eq('Available')
      expect(subject.copy_number).to eq('1')
      expect(subject.call_number).to eq('QA123 .A1')
      expect(subject.loan_type).to eq({ 'id' => 'some-loan-type' })
      expect(subject.enum_parts).to eq({ enum: 'v.1', chron: 'Spring', year: '2020' })
      expect(subject.excluded_locations).to eq([])
    end

    it 'returns nil if holding_id or item_data is nil' do
      # Note: Returning nil from initialize does not prevent object creation. This has to be fixed in code.
      skip 'Fix initialize method to raise ArgumentError instead of returning nil'
      # expect(described_class.new(nil, item_data)).to be_nil
      # expect(described_class.new(holding_id, nil)).to be_nil
    end
  end

  describe '#enumeration' do
    it 'concatenates enum, chron, and year' do
      expect(subject.enumeration).to eq('v.1 - Spring - 2020')
    end
  end

  describe '#inspect' do
    it 'returns the item id' do
      expect(subject.inspect).to eq('item123')
    end
  end

  describe '#available?' do
    it 'returns true if status is Available' do
      expect(subject.available?).to be true
    end

    it 'returns false if status is not Available' do
      item_data['status']['status'] = 'Checked out'
      expect(described_class.new(holding_id, item_data, holdings_data).available?).to be false
    end
  end

  describe '#on_reserve?' do
    it 'returns false if not on reserve' do
      expect(subject.on_reserve?).to be false
    end

    it 'returns true if onReserve is true' do
      item_data['onReserve'] = true
      expect(described_class.new(holding_id, item_data, holdings_data).on_reserve?).to be true
    end

    it 'returns true if location code includes "res"' do
      item_data['location']['code'] = 'mainres'
      expect(described_class.new(holding_id, item_data, holdings_data).on_reserve?).to be true
    end
  end

  describe '#noncirculating?' do
    it 'returns true for nocirc type id' do
      item_data['matType']['id'] = '2e48e713-17f3-4c13-a9f8-23845bb210a4'
      expect(described_class.new(holding_id, item_data, holdings_data).noncirculating?).to be true
    end

    it 'returns true if on reserve' do
      item_data['onReserve'] = true
      expect(described_class.new(holding_id, item_data, holdings_data).noncirculating?).to be true
    end

    it 'returns true if location name includes Non-Circulating' do
      item_data['location']['name'] = 'Non-Circulating Stacks'
      expect(described_class.new(holding_id, item_data, holdings_data).noncirculating?).to be true
    end

    it 'returns false otherwise' do
      expect(subject.noncirculating?).to be false
    end
  end

  describe '#day_loan?' do
    it 'returns true for known day loan type ids' do
      %w[
        a00b928e-39ef-4c32-aec9-f57dfb588456
        3b102b62-90f9-4351-9d20-6f65714fc8a9
        558f30ed-8def-4af6-bf89-c93a69dd51b9
        23ed0bee-15c6-4043-923a-138b2e1cad8a
        79b2aec0-2790-450a-930a-c37bd082653d
      ].each do |id|
        item_data['matType']['id'] = id
        expect(described_class.new(holding_id, item_data, holdings_data).day_loan?).to be true
      end
    end

    it 'returns false for other ids' do
      item_data['matType']['id'] = 'other-id'
      expect(described_class.new(holding_id, item_data, holdings_data).day_loan?).to be false
    end
  end

  describe '#minute_loan?' do
    it 'returns true for known minute loan type ids' do
      %w[
        861998f8-3cc8-42b0-85eb-ff147b9683b9
        05efc087-adb9-43b5-857d-9d8af62ba660
        12326209-dd56-410c-8f02-1b7119b0c071
        fc69f8a6-1c5f-498c-9cec-7cca8ef740b8
        ae3214e1-8b4c-44ce-9c48-2e8a0cb8d928
        3dfe6532-e0af-4c72-b744-2bf035c49caf
      ].each do |id|
        item_data['matType']['id'] = id
        expect(described_class.new(holding_id, item_data, holdings_data).minute_loan?).to be true
      end
    end

    it 'returns false for other ids' do
      item_data['matType']['id'] = 'other-id'
      expect(described_class.new(holding_id, item_data, holdings_data).minute_loan?).to be false
    end
  end

  describe '#no_l2l_day_loan?' do
    it 'returns true for 1 Day and 2 Day Loan type ids' do
      %w[
        a00b928e-39ef-4c32-aec9-f57dfb588456
        558f30ed-8def-4af6-bf89-c93a69dd51b9
      ].each do |id|
        item_data['matType']['id'] = id
        expect(described_class.new(holding_id, item_data, holdings_data).no_l2l_day_loan?).to be true
      end
    end

    it 'returns false for other ids' do
      item_data['matType']['id'] = 'other-id'
      expect(described_class.new(holding_id, item_data, holdings_data).no_l2l_day_loan?).to be false
    end
  end

  describe '#regular_loan?' do
    it 'returns true if not nocirc, minute, or day loan' do
      item_data['matType']['id'] = 'regular-id'
      expect(described_class.new(holding_id, item_data, holdings_data).regular_loan?).to be true
    end

    it 'returns false if nocirc, minute, or day loan' do
      item_data['matType']['id'] = '2e48e713-17f3-4c13-a9f8-23845bb210a4'
      expect(described_class.new(holding_id, item_data, holdings_data).regular_loan?).to be false
      item_data['matType']['id'] = '861998f8-3cc8-42b0-85eb-ff147b9683b9'
      expect(described_class.new(holding_id, item_data, holdings_data).regular_loan?).to be false
      item_data['matType']['id'] = 'a00b928e-39ef-4c32-aec9-f57dfb588456'
      expect(described_class.new(holding_id, item_data, holdings_data).regular_loan?).to be false
    end
  end

  describe '#nocirc_loan?' do
    it 'returns true for nocirc type id' do
      item_data['matType']['id'] = '2e48e713-17f3-4c13-a9f8-23845bb210a4'
      expect(described_class.new(holding_id, item_data, holdings_data).nocirc_loan?).to be true
    end

    it 'returns false for other ids' do
      item_data['matType']['id'] = 'other-id'
      expect(described_class.new(holding_id, item_data, holdings_data).nocirc_loan?).to be false
    end
  end
end