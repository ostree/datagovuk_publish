class Datasets::DatafilesController < ApplicationController
  before_action :set_dataset, only: %i[index new create edit update confirm_delete destroy]
  before_action :set_datafile, only: %i[edit update confirm_delete destroy]

  def index
    @datafiles = @dataset.datafiles
  end

  def new
    @datafile = @dataset.datafiles.build
  end

  def create
    @datafile = @dataset.datafiles.build(datafile_params)

    if @datafile.save(context: :link_form)
      redirect_to dataset_datafiles_path(@dataset.uuid, @dataset.name)
    else
      render :new
    end
  end

  def edit; end

  def update
    @datafile.assign_attributes(datafile_params)
    if @datafile.save(context: :link_form)
      redirect_to dataset_datafiles_path(@dataset.uuid, @dataset.name)
    else
      render :edit
    end
  end

  def confirm_delete
    flash[:alert] = "Are you sure you want to delete ‘#{@datafile.name}’?"
    flash[:link_id] = @datafile.id

    redirect_to dataset_datafiles_path(@dataset.uuid, @dataset.name)
  end

  def destroy
    flash[:deleted] = "Your link ‘#{@datafile.name}’ has been deleted"
    @datafile.destroy!

    redirect_to dataset_datafiles_path(@dataset.uuid, @dataset.name)
  end

private

  def set_dataset
    @dataset = Dataset.find_by(uuid: params[:uuid])
  end

  def set_datafile
    @datafile = Datafile.find(params[:id])
  end

  def datafile_params
    params.require(:datafile).permit(
      :url,
      :name,
      :day,
      :month,
      :year,
      :year,
      :quarter,
    )
  end
end
