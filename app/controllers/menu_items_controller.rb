class MenuItemsController < ApplicationController
  before_action -> { authorize_roles!(:admin) }, except: %i[index show]
  before_action :set_menu_item, only: %i[show update destroy]

  # GET /menu_items?category_id=1&available=true
  def index
    items = MenuItem.order(:name)
    items = items.where(category_id: params[:category_id]) if params[:category_id].present?
    items = items.where(is_available: true) if ActiveModel::Type::Boolean.new.cast(params[:available])

    render json: { menu_items: items.map { |item| menu_item_json(item) } }
  end

  def show
    render json: { menu_item: menu_item_json(@menu_item) }
  end

  def create
    menu_item = MenuItem.new(menu_item_params)

    if menu_item.save
      render json: { menu_item: menu_item_json(menu_item) }, status: :created
    else
      render_errors(menu_item)
    end
  end

  def update
    if @menu_item.update(menu_item_params)
      render json: { menu_item: menu_item_json(@menu_item) }
    else
      render_errors(@menu_item)
    end
  end

  # Items that appear in past orders cannot be deleted (they should be marked
  # unavailable instead), so this can respond with 422.
  def destroy
    if @menu_item.destroy
      head :no_content
    else
      render_errors(@menu_item)
    end
  end

  private

  def set_menu_item
    @menu_item = MenuItem.find(params[:id])
  end

  def menu_item_params
    params.permit(:category_id, :name, :description, :price, :is_available)
  end

  def menu_item_json(item)
    item.slice(:id, :category_id, :name, :description, :is_available)
        .merge("price" => format("%.2f", item.price))
  end
end
