class WorkoutStreak
  MILESTONES = [ 4, 12, 26, 52 ].freeze

  def initialize(user)
    @user = user
    @weekly_goal = user.workout_programs.find_by(active: true)&.program_days&.count
  end

  attr_reader :weekly_goal

  def trackable?
    weekly_goal.present? && weekly_goal.positive?
  end

  def current_week_count
    sessions_by_week[current_week_start] || 0
  end

  private

  attr_reader :user

  def current_week_start
    Date.current.beginning_of_week(:sunday)
  end

  def sessions_by_week
    @sessions_by_week ||= user.workout_sessions.completed.pluck(:finished_at)
      .group_by { |finished_at| finished_at.to_date.beginning_of_week(:sunday) }
      .transform_values(&:count)
  end
end
