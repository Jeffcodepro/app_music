class AddPerformanceFieldsToStudyActivities < ActiveRecord::Migration[7.1]
  def change
    add_column :study_activities, :correct, :boolean
    add_column :study_activities, :source, :string, null: false, default: "legacy"

    add_index :study_activities, %i[user_id source occurred_on]
    add_index :study_activities, %i[user_id area occurred_on]
  end
end
