class DropCircPolicyLocs < ActiveRecord::Migration[7.2]
  def change
    drop_table :blacklight_cornell_requests_circ_policy_locs, if_exists: true
  end
end
