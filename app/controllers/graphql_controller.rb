# frozen_string_literal: true

class GraphqlController < ApplicationController
  # 開発用のディスクストレージで、直接アップロード用 URL のホストを決めるために必要
  include ActiveStorage::SetCurrent

  before_action :authenticate!

  def execute
    result = EmployeeCsvBulkImportSchema.execute(
      params[:query],
      variables: prepare_variables(params[:variables]),
      context: { current_user: @current_user },
      operation_name: params[:operationName]
    )
    render json: result
  end

  private

  # 認証は既存の仕組みを使う前提のため、サンプルではヘッダーでユーザーを指定する簡易実装にしている
  def authenticate!
    @current_user = User.find_by(id: request.headers["X-User-Id"])
    render json: { errors: [ { message: "認証が必要です" } ] }, status: :unauthorized if @current_user.nil?
  end

  def prepare_variables(variables_param)
    case variables_param
    when String then variables_param.present? ? JSON.parse(variables_param) : {}
    when ActionController::Parameters then variables_param.to_unsafe_hash
    when Hash then variables_param
    when nil then {}
    else raise ArgumentError, "Unexpected parameter: #{variables_param}"
    end
  end
end
