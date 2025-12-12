class CondCreateBlacklightCornellRequestsCircPolicyLocs < ActiveRecord::Migration[5.2]
# the attributes in the model are defined in upper case so these must be upper case.
  def up 
    if !ActiveRecord::Base.connection.table_exists? :blacklight_cornell_requests_circ_policy_locs 
      create_table :blacklight_cornell_requests_circ_policy_locs do |t|
        t.integer :CIRC_GROUP_ID, :LOCATION_ID
        t.string  :PICKUP_LOCATION, limit: 1
      end
      add_index :blacklight_cornell_requests_circ_policy_locs, :LOCATION_ID, :name => 'key_location_id'
      add_index :blacklight_cornell_requests_circ_policy_locs, [:CIRC_GROUP_ID, :PICKUP_LOCATION], :name => 'key_cgi_pl'
    end    
  end

  def down 
    drop_table :blacklight_cornell_requests_circ_policy_locs 
  end
end
