class CreatePlaygroundAttempts < ActiveRecord::Migration[7.1]
  def up
    create_table :playground_attempts do |t|
      t.references :user, null: false, foreign_key: true
      t.string :activity, null: false
      t.string :area, null: false
      t.boolean :correct, null: false
      t.date :occurred_on, null: false
      t.datetime :answered_at, null: false
      t.integer :response_time_ms
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :playground_attempts, %i[user_id activity occurred_on]
    add_index :playground_attempts, %i[user_id area occurred_on]
    add_index :playground_attempts, %i[user_id answered_at]

    execute <<~SQL
      INSERT INTO playground_attempts (
        user_id,
        activity,
        area,
        correct,
        occurred_on,
        answered_at,
        metadata,
        created_at,
        updated_at
      )
      SELECT
        user_id,
        area AS activity,
        area,
        correct,
        occurred_on,
        COALESCE(updated_at, created_at, NOW()) AS answered_at,
        '{}'::jsonb,
        created_at,
        updated_at
      FROM study_activities
      WHERE source = 'playground'
        AND correct IS NOT NULL
        AND area IN ('leitura', 'ritmica', 'percepcao', 'harmonia');
    SQL
  end

  def down
    drop_table :playground_attempts
  end
end
