class ChangeCircPolicyGroup < ActiveRecord::Migration[5.2]
  def change
    av = BlacklightCornellRequests::Circ_policy_locs.where(:LOCATION_ID => 216).first
    if !av.nil? 
      av.delete
    end
    av = BlacklightCornellRequests::Circ_policy_locs.create(:CIRC_GROUP_ID => 5, :LOCATION_ID => 216, :PICKUP_LOCATION => 'N')
    av.save!
  end
end
