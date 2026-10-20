class CreateExerciseIntegrityRecords < ActiveRecord::Migration[7.1]
  def change
    create_table :exercise_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.uuid :public_id, null: false
      t.uuid :answer_token, null: false
      t.string :area, null: false
      t.string :rules_version, null: false
      t.jsonb :exercise_payload, null: false
      t.string :content_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :completed_at
      t.timestamps
    end
    add_index :exercise_assignments, :public_id, unique: true
    add_check_constraint :exercise_assignments, "area IN ('leitura', 'percepcao', 'ritmica', 'harmonia')", name: "exercise_assignment_area"

    create_table :exercise_attempts do |t|
      t.references :exercise_assignment, null: false, foreign_key: true
      t.uuid :attempt_token, null: false
      t.string :selected_option_id, null: false
      t.boolean :correct, null: false
      t.integer :xp_earned, null: false, default: 0
      t.timestamps
    end
    add_index :exercise_attempts, [:exercise_assignment_id, :attempt_token], unique: true, name: "unique_exercise_attempt_token"
    add_check_constraint :exercise_attempts, "xp_earned BETWEEN 0 AND 20", name: "exercise_attempt_credit_bounds"

    add_reference :study_activities, :exercise_assignment, foreign_key: true, index: { unique: true }
  end
end
