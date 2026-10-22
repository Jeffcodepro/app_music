module Arena
  class Nickname
    def self.normalize!(value)
      normalized = value.to_s.unicode_normalize(:nfkc).gsub(/[[:space:]]+/, " ").strip
      raise Unavailable, "Use um apelido de 1 a 32 caracteres, sem e-mail ou símbolos especiais." unless normalized.match?(/\A[\p{L}\p{M}\p{N} .'-]{1,32}\z/)
      normalized
    end
  end
end
