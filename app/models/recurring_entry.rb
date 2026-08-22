class RecurringEntry < ApplicationRecord
  enum :kind, { expense: 0, income: 1 }

  belongs_to :category
  has_many :transactions, dependent: :nullify

  validates :description, presence: true
  validates :amount, numericality: { greater_than: 0 }
  validates :day_of_month, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 31 }
  validates :start_date, presence: true

  validate :end_date_after_start_date

  scope :active, -> { where(active: true) }

  private

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?

    errors.add(:end_date, "deve ser posterior à data de início") if end_date < start_date
  end
end
