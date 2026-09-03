class RecurringEntry < ApplicationRecord
  include CategoryOwnership

  enum :kind, { expense: 0, income: 1 }

  belongs_to :user
  belongs_to :category
  has_many :transactions, dependent: :nullify

  validates :description, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :day_of_month, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 31 }
  validates :start_date, presence: true
  validates :installments, numericality: { only_integer: true, greater_than_or_equal_to: 1 }, allow_nil: true

  scope :active, -> { where(active: true) }

  # Computed, not persisted: with `installments` blank, the entry recurs with
  # no end. With N installments, start_date's own month counts as
  # installment 1, so the Nth (last) installment falls (N-1) months later —
  # on day_of_month within that month, clamped to the month's length the
  # same way RecurringEntryGenerator clamps the fire date itself.
  def end_date
    return nil if installments.blank?

    last_month = start_date.beginning_of_month + (installments - 1).months
    day = [ day_of_month, last_month.end_of_month.day ].min
    Date.new(last_month.year, last_month.month, day)
  end
end
