class DropCircPolicyLocs < ActiveRecord::Migration[7.2]
  def change
    drop_table :circ_policy_locs do |t|
      t.integer :CIRC_GROUP_ID
      t.string  :PICKUP_LOCATION
      t.integer :LOCATION_ID
    end
  end
end
