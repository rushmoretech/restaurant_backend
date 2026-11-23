class OrdersController < ApplicationController
  before_action -> { authorize_roles!(:customer, :waiter, :admin) }, only: :create
  before_action :set_order, only: %i[show update]

  # GET /orders?status=pending — customers get their own orders, staff get all.
  def index
    orders = Order.visible_to(current_user)
                  .includes(:restaurant_table, order_items: :menu_item)
                  .order(created_at: :desc, id: :desc)
    orders = orders.where(status: params[:status]) if params[:status].present?

    render json: { orders: orders.map { |order| order_json(order) } }
  end

  def show
    render json: { order: order_json(@order) }
  end

  # POST /orders
  #   { "restaurant_table_id": 3,
  #     "items": [{ "menu_item_id": 1, "quantity": 2, "special_requests": "No onions" }] }
  # Waiters and admins may also pass "user_id" to place the order for a customer.
  def create
    owner = order_owner
    return render json: { errors: [ "User must be an existing customer" ] }, status: :unprocessable_content if owner.nil?

    result = PlaceOrder.call(user: owner, restaurant_table_id: params[:restaurant_table_id],
                             items: order_params[:items])

    if result.success?
      render json: { order: order_json(result.order) }, status: :created
    else
      render json: { errors: result.errors }, status: :unprocessable_content
    end
  end

  # PATCH /orders/:id { "status": "preparing" } — the only thing that can change.
  # Unknown statuses and impossible transitions are 422; a valid transition the
  # user's role may not perform is 403.
  def update
    new_status = params[:status].to_s

    @order.with_lock do
      if !Order.statuses.key?(new_status)
        render json: { errors: [ "Status is not included in the list" ] }, status: :unprocessable_content
      elsif !@order.can_transition_to?(new_status)
        render json: { errors: [ "Cannot change status from #{@order.status} to #{new_status}" ] },
               status: :unprocessable_content
      elsif !@order.transition_permitted_for?(current_user, new_status)
        render json: { error: "You are not allowed to perform this action" }, status: :forbidden
      else
        @order.update!(status: new_status)
        render json: { order: order_json(@order) }
      end
    end
  end

  private

  def set_order
    @order = Order.visible_to(current_user).includes(:restaurant_table, order_items: :menu_item).find(params[:id])
  end

  def order_params
    params.permit(items: %i[menu_item_id quantity special_requests])
  end

  # Customers always order for themselves. Staff may name a customer via user_id.
  def order_owner
    return current_user if current_user.customer? || params[:user_id].blank?

    User.customer.find_by(id: params[:user_id])
  end

  def order_json(order)
    order.slice(:id, :user_id, :restaurant_table_id, :status, :created_at).merge(
      "table_number" => order.restaurant_table&.table_number,
      "total_price" => format("%.2f", order.total_price),
      "items" => order.order_items.map { |item| order_item_json(item) }
    )
  end

  def order_item_json(item)
    item.slice(:id, :menu_item_id, :quantity, :special_requests).merge(
      "name" => item.menu_item.name,
      "unit_price" => format("%.2f", item.unit_price)
    )
  end
end
