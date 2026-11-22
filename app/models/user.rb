class User < ApplicationRecord
  has_secure_password

  enum :role, { customer: 0, waiter: 1, chef: 2, admin: 3 }

  has_many :orders, dependent: :destroy

  validates :first_name, presence: true
  validates :last_name, presence: true
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :role, presence: true
end

