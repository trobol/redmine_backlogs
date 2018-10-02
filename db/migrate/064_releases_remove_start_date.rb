class ReleasesRemoveStartDate < ActiveRecord::Migration
  def self.up
    remove_columns :releases, :release_start_date
  end
  def self.down
    add_column :releases, :release_start_date, :date, :null => false
  end
end
