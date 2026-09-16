require "rails_helper"

RSpec.describe ExerciseCatalogSeeder do
  it "creates every catalog exercise as a global exercise" do
    described_class.call

    expect(Exercise.where(user: nil).count).to eq(ExerciseCatalogSeeder::CATALOG.size)
    expect(Exercise.where(user: nil).pluck(:name)).to match_array(ExerciseCatalogSeeder::CATALOG.map { |attrs| attrs[:name] })
  end

  it "sets kind and muscle_group from the catalog" do
    described_class.call

    supino = Exercise.find_by(name: "Supino Reto", user: nil)
    expect(supino).to be_strength
    expect(supino).to be_chest

    esteira = Exercise.find_by(name: "Esteira", user: nil)
    expect(esteira).to be_cardio
    expect(esteira).to be_legs
  end

  it "is idempotent — running it twice does not create duplicates" do
    described_class.call

    expect { described_class.call }.not_to change(Exercise, :count)
  end

  it "does not overwrite an existing exercise's kind or muscle_group" do
    Exercise.create!(name: "Supino Reto", user: nil, kind: :cardio, muscle_group: :legs)

    described_class.call

    supino = Exercise.find_by(name: "Supino Reto", user: nil)
    expect(supino).to be_cardio
    expect(supino).to be_legs
    expect(Exercise.where(name: "Supino Reto", user: nil).count).to eq(1)
  end

  it "does not touch a different user's custom exercise with the same name" do
    user = create(:user)
    custom = Exercise.create!(name: "Supino Reto", user: user, kind: :cardio, muscle_group: :legs)

    described_class.call

    expect(custom.reload.kind).to eq("cardio")
    expect(Exercise.where(name: "Supino Reto", user: nil).count).to eq(1)
  end
end
