require "test_helper"

class CategoryTest < ActiveSupport::TestCase
  test "fixtures are valid" do
    Category.find_each { |category| assert category.valid?, category.errors.full_messages.to_sentence }
  end

  test "valid with a name" do
    assert Category.new(name: "Desserts").valid?
  end

  test "description is optional" do
    assert Category.new(name: "Drinks", description: nil).valid?
  end

  test "requires a name" do
    category = Category.new(name: nil)
    assert_not category.valid?
    assert_includes category.errors[:name], "can't be blank"
  end

  test "name must be unique regardless of case" do
    category = Category.new(name: categories(:starters).name.downcase)
    assert_not category.valid?
    assert_includes category.errors[:name], "has already been taken"
  end

  test "database enforces name uniqueness" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      Category.new(name: categories(:starters).name).save(validate: false)
    end
  end

  test "has many menu items" do
    assert_includes categories(:starters).menu_items, menu_items(:soup)
    assert_includes categories(:mains).menu_items, menu_items(:steak)
  end

  test "destroying a category destroys its menu items" do
    category = Category.create!(name: "Desserts")
    category.menu_items.create!(name: "Cake", price: 15)
    assert_difference "MenuItem.count", -1 do
      category.destroy
    end
  end

  test "cannot be destroyed while a menu item has been ordered" do
    category = categories(:starters)

    assert_no_difference [ "Category.count", "MenuItem.count" ] do
      assert_not category.destroy
    end
    assert_includes category.errors[:base], "Cannot delete a category that has menu items used in orders"
  end
end
