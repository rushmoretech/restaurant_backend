class RestaurantTablesController < ApplicationController
  before_action -> { authorize_roles!(:admin) }, only: %i[create destroy]
  before_action -> { authorize_roles!(:admin, :waiter) }, only: :update
  before_action :set_table, only: %i[show update destroy]

  # GET /restaurant_tables?status=available
  def index
    tables = RestaurantTable.order(:table_number)
    tables = tables.where(status: params[:status]) if params[:status].present?

    render json: { restaurant_tables: tables.map { |table| table_json(table) } }
  end

  def show
    render json: { restaurant_table: table_json(@table) }
  end

  def create
    table = RestaurantTable.new(table_params)

    if table.save
      render json: { restaurant_table: table_json(table) }, status: :created
    else
      render_errors(table)
    end
  end

  # Waiters can only change a table's status (e.g. seat or free a table);
  # any other attribute they send is ignored.
  def update
    if @table.update(table_params)
      render json: { restaurant_table: table_json(@table) }
    else
      render_errors(@table)
    end
  end

  # Orders placed at the table are kept (their table is cleared).
  def destroy
    @table.destroy!
    head :no_content
  end

  private

  def set_table
    @table = RestaurantTable.find(params[:id])
  end

  def table_params
    if current_user.admin?
      params.permit(:table_number, :seats, :status)
    else
      params.permit(:status)
    end
  end

  def table_json(table)
    table.slice(:id, :table_number, :seats, :status)
  end
end
