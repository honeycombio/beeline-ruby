class BeesController < ApplicationController
  before_action :set_bee, only: [:show, :edit, :update, :destroy]

  # GET /bees
  # GET /bees.json
  def index
    @bees = Bee.all
  end

  # GET /bees/1
  # GET /bees/1.json
  def show
  end

  # GET /bees/new
  def new
    @bee = Bee.new
  end

  # GET /bees/1/edit
  def edit
  end

  # POST /bees
  # POST /bees.json
  def create
    @bee = Bee.new(bee_params)

    respond_to do |format|
      if @bee.save
        format.html { redirect_to @bee, notice: 'Bee was successfully created.' }
        format.json { render :show, status: :created, location: @bee }
      else
        format.html { render :new }
        format.json { render json: @bee.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /bees/1
  # PATCH/PUT /bees/1.json
  def update
    respond_to do |format|
      if @bee.update(bee_params)
        format.html { redirect_to @bee, notice: 'Bee was successfully updated.' }
        format.json { render :show, status: :ok, location: @bee }
      else
        format.html { render :edit }
        format.json { render json: @bee.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /bees/1
  # DELETE /bees/1.json
  def destroy
    @bee.destroy
    respond_to do |format|
      format.html { redirect_to bees_url, notice: 'Bee was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_bee
      @bee = Bee.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def bee_params
      params.require(:bee).permit(:name)
    end
end
