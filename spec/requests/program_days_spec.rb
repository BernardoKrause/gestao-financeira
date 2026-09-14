require "rails_helper"

RSpec.describe "ProgramDays", type: :request do
  let(:user) { create(:user) }
  let(:program) { create(:workout_program, user: user) }

  before { sign_in user }

  it "adds a day to the program" do
    expect {
      post workout_program_program_days_path(program), params: { program_day: { label: "A", title: "Peito e Tríceps" } }
    }.to change(program.program_days, :count).by(1)

    expect(response).to redirect_to(edit_workout_program_path(program))
  end

  it "does not add a day without a label" do
    expect {
      post workout_program_program_days_path(program), params: { program_day: { label: "", title: "Peito" } }
    }.not_to change(ProgramDay, :count)
  end

  it "removes a day" do
    day = create(:program_day, workout_program: program)
    expect { delete workout_program_program_day_path(program, day) }.to change(ProgramDay, :count).by(-1)
  end

  it "reorders days" do
    first = create(:program_day, workout_program: program, position: 0)
    second = create(:program_day, workout_program: program, position: 1)

    patch reorder_workout_program_program_days_path(program), params: { ids: [ second.id, first.id ] }, as: :json

    expect(response).to have_http_status(:no_content)
    expect(second.reload.position).to eq(0)
    expect(first.reload.position).to eq(1)
  end

  it "returns 404 when acting on another user's program" do
    other_program = create(:workout_program)

    post workout_program_program_days_path(other_program), params: { program_day: { label: "A", title: "Peito" } }
    expect(response).to have_http_status(:not_found)
  end
end
