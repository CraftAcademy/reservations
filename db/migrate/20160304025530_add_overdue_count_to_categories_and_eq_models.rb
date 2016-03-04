class AddOverdueCountToCategoriesAndEqModels < ActiveRecord::Migration

  def self.up

    add_column :categories, :overdue_count, :integer, :null => false, :default => 0
    add_column :equipment_models, :overdue_count, :integer, :null => false, :default => 0
    Reservation.counter_culture_fix_counts

  end

  def self.down

    remove_column :categories, :overdue_count
    remove_column :equipment_models, :overdue_count

  end

end
