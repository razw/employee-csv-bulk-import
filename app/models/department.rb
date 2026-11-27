class Department < ApplicationRecord
  belongs_to :tenant
  has_many :employees
end
