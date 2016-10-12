require 'spec_helper'

describe "shared/_reqpu.html.haml" do

  it "shows an option for faculty office delivery when eligible" do
    assign(:fod_eligible, true)
    render
    expect(rendered).to have_select 'library_id', with_options: ['Faculty Office Delivery']
  end

  it "does not show an option for faculty office delivery when not eligible" do
    assign(:fod_eligible, false)
    render
    expect(rendered).not_to have_select 'library_id', with_options: ['Faculty Office Delivery']
  end

end
