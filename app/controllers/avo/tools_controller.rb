class Avo::ToolsController < Avo::ApplicationController
  def overview
    @page_title = "Visão geral"
    add_breadcrumb title: "Visão geral"

    @users_count = User.count
    @categories_count = Category.count
    @transactions_count = Transaction.count
    @recurring_entries_count = RecurringEntry.count
  end
end
