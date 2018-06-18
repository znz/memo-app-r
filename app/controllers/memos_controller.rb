# frozen_string_literal: true

require 'resolv'

class MemosController < ApplicationController
  before_action :set_memo, only: %i[show edit update destroy]

  # GET /memos
  # GET /memos.json
  def index
    @memos = Memo.all
    @q = @memos.ransack(params[:q])
    @q.sorts = 'created_at desc' if @q.sorts.empty?
    @memos = @q.result(distinct: true)
    @memos = @memos.page(params[:page])
  end

  # GET /memos/1
  # GET /memos/1.json
  def show; end

  # GET /memos/new
  def new
    @memo = Memo.new
  end

  # GET /memos/1/edit
  def edit; end

  # POST /memos
  # POST /memos.json
  def create
    @memo = Memo.new(memo_params)
    @memo.user = current_user
    ip = request.remote_ip
    @memo.create_from = ip
    begin
      @memo.hostname = Resolv.getname(ip)
    rescue Resolv::ResolvError
      # ignore
    end
    @memo.user_agent = request.env['HTTP_USER_AGENT']

    respond_to do |format|
      if @memo.save
        format.html { redirect_to @memo, notice: 'Memo was successfully created.' }
        format.json { render :show, status: :created, location: @memo }
      else
        format.html { render :new }
        format.json { render json: @memo.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /memos/1
  # PATCH/PUT /memos/1.json
  def update
    respond_to do |format|
      if @memo.update(memo_params)
        format.html { redirect_to @memo, notice: 'Memo was successfully updated.' }
        format.json { render :show, status: :ok, location: @memo }
      else
        format.html { render :edit }
        format.json { render json: @memo.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /memos/1
  # DELETE /memos/1.json
  def destroy
    @memo.destroy
    respond_to do |format|
      format.html { redirect_to memos_url, notice: 'Memo was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_memo
    @memo = Memo.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def memo_params
    params.require(:memo).permit(:info, :content, :price, :category, :lonlat, tags: [])
  end
end
