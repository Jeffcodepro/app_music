# Presentation is derived from structured facts. A future locale can select a
# different template set without changing pitch, degree or position validation.
module ExercisePresentation
  NOTE_LABELS = { "C" => "Dó", "D" => "Ré", "E" => "Mi", "F" => "Fá", "G" => "Sol", "A" => "Lá", "B" => "Si" }.freeze
  PITCH_ACCIDENTAL_LABELS = { "#" => "sustenido", "##" => "duplo sustenido", "b" => "bemol", "bb" => "duplo bemol" }.freeze
  ACCIDENTALS = {
    "sharp" => { symbol: "♯", label: "Sustenido", alter: 1 }.freeze,
    "flat" => { symbol: "♭", label: "Bemol", alter: -1 }.freeze,
    "natural" => { symbol: "♮", label: "Bequadro", alter: 0 }.freeze,
    "double_sharp" => { symbol: "𝄪", label: "Duplo sustenido", alter: 2 }.freeze,
    "double_flat" => { symbol: "𝄫", label: "Duplo bemol", alter: -2 }.freeze
  }.freeze
  INTERVAL_QUESTION = "Ouça duas notas consecutivas e identifique o intervalo melódico.".freeze
  DIRECTION_MODES = { "ascending" => "Ascendente", "descending" => "Descendente", "mixed" => "Misto" }.freeze
  DIRECTIONS = { "ascending" => "Crescente", "descending" => "Decrescente" }.freeze

  def self.pitch_label(pitch_name)
    note = MusicTheory::Note.parse(pitch_name)
    accidental = PITCH_ACCIDENTAL_LABELS[MusicTheory::Note::ASCII_ALTERATIONS.fetch(note.alter)]
    [NOTE_LABELS.fetch(note.step), accidental, note.octave].compact.join(" ")
  rescue ArgumentError
    pitch_name.to_s # Preserve the existing localization fallback for unknown text.
  end

  # Legacy Reading payloads store the natural staff pitch separately from the
  # printed accidental. These exercises contain one isolated note, no key or
  # preceding accidental context. This is not a general notation-state resolver.
  def self.reading_note(exercise)
    type = exercise.fetch(:question_type)
    raise ArgumentError, "reading exercise must contain a note" unless %w[note_name accidental].include?(type)
    note = MusicTheory::Note.parse(exercise.fetch(:pitch_name))
    raise ArgumentError, "legacy staff pitch must be natural" unless note.alter.zero?
    return note if type == "note_name"

    note.with_alter(ACCIDENTALS.fetch(exercise.fetch(:note_accidental_id)).fetch(:alter))
  end

  def self.ordinal(position)
    "#{position}ª posição"
  end

  def self.progression_question(position)
    "Ouça a progressão inteira e identifique qual grau apareceu na #{ordinal(position)}."
  end

  def self.progression_prompt(position)
    "Qual grau apareceu na #{ordinal(position)}?"
  end

  def self.progression_steps(length, focus)
    (1..length).map do |position|
      { roman: ordinal(position), notes: position == focus ? "Responda esta posição" : "Memorize o acorde ouvido", focus: position == focus }
    end
  end
end
