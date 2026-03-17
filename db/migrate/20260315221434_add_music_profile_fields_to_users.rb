class AddMusicProfileFieldsToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :full_name, :string
    add_column :users, :phone, :string
    add_column :users, :age_range, :string
    add_column :users, :primary_instrument, :string
    add_column :users, :secondary_instrument, :string
    add_column :users, :musical_level, :string
    add_column :users, :study_goal, :string
    add_column :users, :weekly_study_minutes, :integer
    add_column :users, :learning_mode, :string
    add_column :users, :city, :string
    add_column :users, :state, :string
    add_column :users, :plan, :string
    add_column :users, :accepted_terms, :boolean
  end
end
