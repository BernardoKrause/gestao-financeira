require "rails_helper"

RSpec.describe WorkoutSession, type: :model do
  it "is valid with a user, workout_program, program_day and started_at" do
    expect(build(:workout_session)).to be_valid
  end

  it "is invalid without started_at" do
    expect(build(:workout_session, started_at: nil)).not_to be_valid
  end

  it "defaults to in_progress" do
    expect(create(:workout_session).status).to eq("in_progress")
  end

  it "can be marked completed" do
    expect(create(:workout_session, :completed).status).to eq("completed")
  end

  it "is destroyed along with its set_logs" do
    session = create(:workout_session)
    create(:set_log, workout_session: session)

    expect { session.destroy }.to change(SetLog, :count).by(-1)
  end
end
