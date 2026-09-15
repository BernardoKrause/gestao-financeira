class WorkoutHistoryController < ApplicationController
  PERIODS = %w[1m 3m all].freeze
  PT_MONTHS = %w[janeiro fevereiro março abril maio junho julho agosto setembro outubro novembro dezembro].freeze

  helper_method :month_label

  def index
    load_calendar_data
    load_progress_chart_data
  end

  def chart
    load_progress_chart_data
    respond_to(&:turbo_stream)
  end

  def show
    @workout_session = current_user.workout_sessions.completed.order(:finished_at).find_by!(finished_at: parsed_date.all_day)
    @program_exercises = @workout_session.program_day.program_exercises.includes(:exercise).order(:position)
    @set_logs_by_program_exercise = @workout_session.set_logs.includes(program_exercise: :exercise).order(:position).group_by(&:program_exercise_id)
  end

  private

  def load_calendar_data
    @month = parsed_month
    @previous_month = @month.prev_month
    @next_month = @month.next_month
    @month_label = month_label(@month)
    @calendar_weeks = calendar_weeks(@month)
    @completed_dates = WorkoutSession.completed_dates_for(user: current_user, month: @month)
  end

  def parsed_month
    Date.strptime(params[:month], "%Y-%m").beginning_of_month
  rescue ArgumentError, TypeError
    Date.current.beginning_of_month
  end

  def parsed_date
    Date.iso8601(params[:date])
  rescue ArgumentError
    raise ActiveRecord::RecordNotFound
  end

  def calendar_weeks(month)
    first_day = month.beginning_of_month
    last_day = month.end_of_month
    cells = Array.new(first_day.wday) + (first_day..last_day).to_a + Array.new(6 - last_day.wday)
    cells.each_slice(7).to_a
  end

  def month_label(date)
    "#{PT_MONTHS[date.month - 1].capitalize} de #{date.year}"
  end

  def load_progress_chart_data
    @progress_summary = SetLog.strength_progress_summary(current_user)
    @exercise_options = Exercise.where(id: @progress_summary.keys).order(:name).to_a
    default_exercise_id = @progress_summary.max_by { |_, last_at| last_at }&.first
    @selected_exercise_id = params[:exercise_id].presence_in(@exercise_options.map { |e| e.id.to_s }) || default_exercise_id&.to_s
    @selected_period = params[:period].presence_in(PERIODS) || "3m"
    @selected_exercise = @exercise_options.find { |e| e.id.to_s == @selected_exercise_id }

    if @selected_exercise_id
      grouped = SetLog.max_weight_by_day(user: current_user, exercise_id: @selected_exercise_id, since: period_since(@selected_period))
      sorted = grouped.sort_by { |date, _| date }
      @progress_chart_labels = sorted.map { |date, _| date.strftime("%d/%m") }
      @progress_chart_data = sorted.map { |_, weight| weight.to_f }
    else
      @progress_chart_labels = []
      @progress_chart_data = []
    end
  end

  def period_since(period)
    case period
    when "1m" then 1.month.ago.to_date
    when "3m" then 3.months.ago.to_date
    end
  end
end
