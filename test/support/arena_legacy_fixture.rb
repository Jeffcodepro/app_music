# Synthetic history only. No development records or published musical content.
module ArenaLegacyFixture
  TABLES = %w[arena_rooms arena_participants arena_round_questions arena_responses].freeze

  def self.seed!(connection)
    connection.exec(<<~SQL)
      INSERT INTO users(id,email,encrypted_password,full_name,created_at,updated_at) VALUES
        (701,'host@arena-fixture.test','','Synthetic host',now(),now()),
        (702,'learner@arena-fixture.test','','Synthetic learner',now(),now());
      INSERT INTO arena_rooms(id,host_id,title,room_code,theme,question_kind,question_count,
        question_duration_seconds,difficulty,advance_mode,created_at,updated_at) VALUES
        (901,701,'Synthetic legacy room','FIXTURE','synthetic','visual',1,30,'fixture','manual',now(),now());
      INSERT INTO arena_participants(id,arena_room_id,user_id,nickname,joined_at,created_at,updated_at) VALUES
        (801,901,702,'Synthetic participant',now(),now(),now());
      INSERT INTO arena_round_questions(id,arena_room_id,position,theme,prompt_kind,source_kind,
        question_text,correct_slot_key,content_data,answer_slots,created_at,updated_at) VALUES
        (1001,901,1,'synthetic','visual','fixture','Synthetic preservation fixture','b',
          '{"fixture":true}','["a","b","c","d"]',now(),now());
      INSERT INTO arena_responses(id,arena_round_question_id,arena_participant_id,slot_key,option_id,
        correct,points_awarded,response_time_ms,answered_at,created_at,updated_at) VALUES
        (1101,1001,801,'b','fixture-b',true,7,500,now(),now(),now());
      SELECT setval('users_id_seq',1702,true);
      SELECT setval('arena_rooms_id_seq',1901,true);
      SELECT setval('arena_participants_id_seq',1801,true);
      SELECT setval('arena_round_questions_id_seq',2001,true);
      SELECT setval('arena_responses_id_seq',2101,true);
    SQL
  end
end
