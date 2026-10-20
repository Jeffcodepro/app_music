class CreateDailyVisits < ActiveRecord::Migration[7.1]
  def change
    create_table :daily_visits do |t|
      t.references :user, null: false, foreign_key: true
      t.date :visited_on, null: false
      t.timestamps
    end
    add_index :daily_visits, [:user_id, :visited_on], unique: true
  end
end
