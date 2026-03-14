class ProcessTemplatesController < ApplicationController
  def index
    @residential_templates = ProcessTemplate.residential
    @commercial_templates  = ProcessTemplate.commercial
    @templates             = ProcessTemplate.ordered # fallback for create errors
    @new_template          = ProcessTemplate.new
  end

  def create
    @template = ProcessTemplate.new(template_params)
    max_pos = ProcessTemplate.maximum(:position) || 0
    @template.position = max_pos + 1
    @template.is_default = false

    if @template.save
      redirect_to process_templates_path, notice: "템플릿이 추가되었습니다."
    else
      @templates = ProcessTemplate.ordered
      @new_template = @template
      render :index, status: :unprocessable_entity
    end
  end

  def destroy
    @template = ProcessTemplate.find(params[:id])
    @template.destroy
    redirect_to process_templates_path, notice: "템플릿이 삭제되었습니다."
  end

  def move_up
    template = ProcessTemplate.find(params[:id])
    prev = ProcessTemplate.where("position < ?", template.position).order(position: :desc).first
    if prev
      template.position, prev.position = prev.position, template.position
      template.save!
      prev.save!
    end
    redirect_to process_templates_path
  end

  def move_down
    template = ProcessTemplate.find(params[:id])
    nxt = ProcessTemplate.where("position > ?", template.position).order(position: :asc).first
    if nxt
      template.position, nxt.position = nxt.position, template.position
      template.save!
      nxt.save!
    end
    redirect_to process_templates_path
  end

  private

  def template_params
    params.require(:process_template).permit(:name)
  end
end
