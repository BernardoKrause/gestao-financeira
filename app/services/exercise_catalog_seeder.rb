class ExerciseCatalogSeeder
  CATALOG = [
    { name: "Supino Reto", kind: :strength, muscle_group: :chest },
    { name: "Supino Inclinado", kind: :strength, muscle_group: :chest },
    { name: "Crucifixo", kind: :strength, muscle_group: :chest },
    { name: "Flexão de Braço", kind: :strength, muscle_group: :chest },

    { name: "Tríceps Testa", kind: :strength, muscle_group: :triceps },
    { name: "Tríceps Corda", kind: :strength, muscle_group: :triceps },
    { name: "Mergulho", kind: :strength, muscle_group: :triceps },

    { name: "Puxada Frontal", kind: :strength, muscle_group: :back },
    { name: "Remada Curvada", kind: :strength, muscle_group: :back },
    { name: "Levantamento Terra", kind: :strength, muscle_group: :back },
    { name: "Barra Fixa", kind: :strength, muscle_group: :back },

    { name: "Rosca Direta", kind: :strength, muscle_group: :biceps },
    { name: "Rosca Alternada", kind: :strength, muscle_group: :biceps },
    { name: "Rosca Martelo", kind: :strength, muscle_group: :biceps },

    { name: "Agachamento", kind: :strength, muscle_group: :legs },
    { name: "Leg Press", kind: :strength, muscle_group: :legs },
    { name: "Cadeira Extensora", kind: :strength, muscle_group: :legs },
    { name: "Afundo", kind: :strength, muscle_group: :legs },

    { name: "Elevação Pélvica", kind: :strength, muscle_group: :glutes },
    { name: "Cadeira Abdutora", kind: :strength, muscle_group: :glutes },
    { name: "Stiff", kind: :strength, muscle_group: :glutes },

    { name: "Desenvolvimento", kind: :strength, muscle_group: :shoulders },
    { name: "Elevação Lateral", kind: :strength, muscle_group: :shoulders },
    { name: "Elevação Frontal", kind: :strength, muscle_group: :shoulders },

    { name: "Abdominal Reto", kind: :strength, muscle_group: :abs },
    { name: "Prancha", kind: :strength, muscle_group: :abs },
    { name: "Elevação de Pernas", kind: :strength, muscle_group: :abs },

    { name: "Esteira", kind: :cardio, muscle_group: :legs },
    { name: "Bicicleta Ergométrica", kind: :cardio, muscle_group: :legs },
    { name: "Elíptico", kind: :cardio, muscle_group: :legs },
    { name: "Pular Corda", kind: :cardio, muscle_group: :legs },

    { name: "Alongamento de Isquiotibiais", kind: :stretching, muscle_group: :legs },
    { name: "Alongamento de Panturrilha", kind: :stretching, muscle_group: :legs },
    { name: "Alongamento de Ombro", kind: :stretching, muscle_group: :shoulders },
    { name: "Alongamento de Coluna", kind: :stretching, muscle_group: :back }
  ].freeze

  def self.call
    new.call
  end

  def call
    CATALOG.each do |attrs|
      Exercise.find_or_create_by!(name: attrs[:name], user: nil) do |exercise|
        exercise.kind = attrs[:kind]
        exercise.muscle_group = attrs[:muscle_group]
      end
    end
  end
end
