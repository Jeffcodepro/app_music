class CreateStudyActivities < ActiveRecord::Migration[7.1]
  def change
    create_table :study_activities do |t|
      t.references :user, null: false, foreign_key: true
      t.string :area, null: false
      t.integer :xp_earned, null: false, default: 0
      t.integer :minutes_practiced, null: false, default: 0
      t.date :occurred_on, null: false

      t.timestamps
    end

    add_index :study_activities, %i[user_id occurred_on]
  end
end
