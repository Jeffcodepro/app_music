module Arena
  module Avatars
    CHOICES = { "fox" => "Raposa", "cat" => "Gato", "owl" => "Coruja", "robot" => "Robô", "penguin" => "Pinguim", "octopus" => "Polvo", "rabbit" => "Coelho", "dog" => "Cachorro", "bear" => "Urso", "panda" => "Panda", "frog" => "Sapo", "dragon" => "Dragão" }.freeze
    IDS = (["neutral"] + CHOICES.keys).freeze

    def self.validate!(value)
      raise Unavailable, "Escolha um personagem para entrar no jogo." unless CHOICES.key?(value)
      value
    end
  end
end
