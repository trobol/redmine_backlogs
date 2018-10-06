class ChangeNullFalseToTrueForReleases < ActiveRecord::Migration
  def up
    change_column_null :releases, :release_end_date, true
  end
  def down
    change_column_null :releases, :release_end_date, false
  end
end
