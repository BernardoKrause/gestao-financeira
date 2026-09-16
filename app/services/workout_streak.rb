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

  def current_streak_weeks
    return 0 unless trackable?

    week = current_week_start
    week -= 1.week unless week_met?(week)

    count = 0
    while week_met?(week)
      count += 1
      week -= 1.week
    end
    count
  end

  def longest_streak_weeks
    return 0 unless trackable?
    return 0 if sessions_by_week.empty?

    week = sessions_by_week.keys.min
    longest = 0
    running = 0

    while week <= current_week_start
      if week_met?(week)
        running += 1
        longest = [ longest, running ].max
      else
        running = 0
      end
      week += 1.week
    end

    longest
  end

  def unlocked_badges
    MILESTONES.select { |milestone| longest_streak_weeks >= milestone }
  end

  private

  attr_reader :user

  def week_met?(week)
    (sessions_by_week[week] || 0) >= weekly_goal
  end

  def current_week_start
    Date.current.beginning_of_week(:sunday)
  end

  def sessions_by_week
    @sessions_by_week ||= user.workout_sessions.completed.pluck(:finished_at)
      .group_by { |finished_at| finished_at.to_date.beginning_of_week(:sunday) }
      .transform_values(&:count)
  end
end
