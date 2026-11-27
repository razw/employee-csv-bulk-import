class Tenant < ApplicationRecord
  has_many :users
  has_many :departments
  has_many :employees
  has_many :employee_imports
end
