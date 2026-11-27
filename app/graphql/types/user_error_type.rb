# frozen_string_literal: true

module Types
  class UserErrorType < Types::BaseObject
    description "利用者が修正できるエラー (入力値の誤りなど)"
    field :message, String, null: false, description: "利用者に見せるメッセージ"
  end
end
