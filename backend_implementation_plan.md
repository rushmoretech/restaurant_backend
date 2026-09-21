# Backend Implementation Plan: Restaurant Application

**Tech Stack:** Ruby on Rails (API-only mode) + PostgreSQL

## 1. Project Initialization

The application will be built from scratch, optimized exclusively to serve data via API to the frontend (no Views).

* **Setup command:**

  ```bash
  rails new restaurant_backend --api -d postgresql
  cd restaurant_backend
  rails db:create
  
  ```

## 2. Database Schema and Associations (ActiveRecord)

The database will be PostgreSQL, and the structure will be defined via Rails models and migrations.

* **User:** Manages roles (`enum role: { customer: 0, waiter: 1, chef: 2, admin: 3 }`). 
  * *Associations:* `has_many :orders`
  * *Fields:* `first_name`, `last_name`, `email`, `password_digest`, `role`

* **Category:** Menu categories (e.g., Drinks, Main Course). 
  * *Associations:* `has_many :menu_items`
  * *Fields:* `name`, `description`

* **MenuItem:** The products in the menu. 
  * *Associations:* `belongs_to :category`, `has_many :order_items`
  * *Fields:* `name`, `description`, `price`, `is_available`

* **RestaurantTable:** Physical tables management. 
  * *Rails Magic:* `enum status: { available: 0, occupied: 1, reserved: 2 }`
  * *Fields:* `table_number`, `seats`, `status`

* **Order:** The main order record. 
  * *Associations:* `belongs_to :user`, `belongs_to :restaurant_table, optional: true`, `has_many :order_items`
  * *Rails Magic:* `enum status: { pending: 0, preparing: 1, ready: 2, delivered: 3, cancelled: 4 }`
  * *Fields:* `total_price`, `status`

* **OrderItem:** The individual line items within an order. 
  * *Associations:* `belongs_to :order`, `belongs_to :menu_item`
  * *Fields:* `quantity`, `unit_price` (saved at the time of order to prevent future menu price changes from affecting history), `special_requests` (e.g., "No onions").

## 3. Authentication, Security, and Roles (JWT)

Since this is an API, authentication will rely on tokens rather than classic sessions/cookies.

* **Implementation:** Use `has_secure_password` (native to Rails) alongside the `jwt` gem.
* **Flow:** At the `/login` endpoint, the user provides credentials and receives a valid JWT token.
* **Authorization:** The frontend sends the `Authorization: Bearer <token>` header for secured requests. The backend verifies the token and the user's role (e.g., ensuring only a user with `role: :chef` can update an order's status to "preparing").

## 4. Real-Time Features (ActionCable)

The kitchen experience and client notifications must be instantaneous.

* **Technology:** ActionCable (WebSockets built natively into Rails).
* **Flow (KDS - Kitchen Display System):**
  * Create a `KitchenOrdersChannel`.
  * In the `Order` model, use an `after_update_commit` callback to check if the status has changed.
  * When an order becomes active, the server automatically broadcasts the updated order data to all subscribers in the kitchen, updating the tablet UI without a page refresh.

## 5. Background Jobs (Asynchronous Tasks)

Time-consuming processes must not block the API response time.

* **Technology:** Solid Queue (highly recommended for modern Rails versions) or Sidekiq.
* **Use Cases:**
  * Sending order confirmation or receipt emails to customers.
  * Processing credit card payments via third-party services (e.g., Stripe).
  * Cleaning up "abandoned" pending orders from the database.

## 6. Data Serialization (JSON)

Raw data from models must be formatted and sanitized before being sent as a JSON response.

* **Technology:** The `blueprinter` gem (fast and object-based) or `active_model_serializers`.
* **Purpose:** Hiding sensitive data (passwords, internal timestamps) and structuring nested info. For instance, a `GET /orders/:id` endpoint will return the order object, nesting a list of all `order_items` and their associated product details.