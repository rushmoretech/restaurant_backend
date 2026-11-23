class CategoriesController < ApplicationController
  before_action -> { authorize_roles!(:admin) }, except: %i[index show]
  before_action :set_category, only: %i[show update destroy]

  def index
    render json: { categories: Category.order(:name).map { |category| category_json(category) } }
  end

  def show
    render json: { category: category_json(@category) }
  end

  def create
    category = Category.new(category_params)

    if category.save
      render json: { category: category_json(category) }, status: :created
    else
      render_errors(category)
    end
  end

  def update
    if @category.update(category_params)
      render json: { category: category_json(@category) }
    else
      render_errors(@category)
    end
  end

  def destroy
    if @category.destroy
      head :no_content
    else
      render_errors(@category)
    end
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.permit(:name, :description)
  end

  def category_json(category)
    category.slice(:id, :name, :description)
  end
end
