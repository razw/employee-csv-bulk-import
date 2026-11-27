# frozen_string_literal: true

module Types
  class MutationType < Types::BaseObject
    field :create_direct_upload, mutation: Mutations::CreateDirectUpload
    field :create_employee_import, mutation: Mutations::CreateEmployeeImport
  end
end
