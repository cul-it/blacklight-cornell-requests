require 'rails_helper'

RSpec.describe BlacklightCornellRequests::Volume do
  let(:item1) { double(enum_parts: { enum: 'v.1', chron: 'Spring', year: '2020' }) }
  let(:item2) { double(enum_parts: { enum: 'v.1', chron: 'Spring', year: '2020' }) }
  let(:item3) { double(enum_parts: { enum: 'v.2', chron: 'Fall', year: '2021' }) }

  describe '.volumes' do
    it 'groups items by volume and returns unique volumes' do
      volumes = described_class.volumes([item1, item2, item3])
      expect(volumes.size).to eq(2)
      expect(volumes.map(&:enumeration)).to contain_exactly('v.1 - Spring - 2020', 'v.2 - Fall - 2021')
      expect(volumes.find { |v| v.enum == 'v.1' }.items).to include(item1, item2)
      expect(volumes.find { |v| v.enum == 'v.2' }.items).to include(item3)
    end
  end

  describe '.volume_from_params' do
    it 'parses a param string and returns a Volume' do
      v = described_class.volume_from_params('|v.3|Winter|2022|')
      expect(v.enum).to eq('v.3')
      expect(v.chron).to eq('Winter')
      expect(v.year).to eq('2022')
    end

    it 'returns nil for invalid param string' do
      expect(described_class.volume_from_params('invalid')).to be_nil
    end
  end

  describe '#enumeration' do
    it 'concatenates enum, chron, and year' do
      v = described_class.new('v.4', 'Summer', '2023')
      expect(v.enumeration).to eq('v.4 - Summer - 2023')
    end

    it 'handles missing fields gracefully' do
      v = described_class.new('v.5', nil, '2024')
      expect(v.enumeration).to eq('v.5 - 2024')
    end
  end

  describe '#select_option' do
    it 'returns a formatted select string' do
      v = described_class.new('v.6', 'Autumn', '2025')
      expect(v.select_option).to eq('|v.6|Autumn|2025|')
    end
  end

  describe '#add_item and #remove_item' do
    it 'adds and removes items from the volume' do
      v = described_class.new('v.7', 'Spring', '2026')
      v.add_item('itemA')
      expect(v.items).to include('itemA')
      v.remove_item('itemA')
      expect(v.items).not_to include('itemA')
    end
  end

  describe '#==' do
    it 'compares volumes by state' do
      v1 = described_class.new('v.8', 'Winter', '2027')
      v2 = described_class.new('v.8', 'Winter', '2027')
      v3 = described_class.new('v.9', 'Winter', '2027')
      expect(v1).to eq(v2)
      expect(v1).not_to eq(v3)
    end
  end

  describe '#eql? and #hash' do
    it 'supports hash-based equality' do
      v1 = described_class.new('v.10', 'Spring', '2028')
      v2 = described_class.new('v.10', 'Spring', '2028')
      hash = { v1 => 'foo' }
      expect(hash[v2]).to eq('foo')
    end
  end
end