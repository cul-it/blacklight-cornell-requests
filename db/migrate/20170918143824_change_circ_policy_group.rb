class ChangeCircPolicyGroup < ActiveRecord::Migration
  def change
    av = BlacklightCornellRequests::Circ_policy_locs.where(:LOCATION_ID => 216).first
    av.delete
    BlacklightCornellRequests::Circ_policy_locs.create(:CIRC_GROUP_ID => 5, :LOCATION_ID => 216, :PICKUP_LOCATION => 'N')
    av.save!
  end
end
