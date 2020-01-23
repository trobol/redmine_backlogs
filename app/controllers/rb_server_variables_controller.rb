class RbServerVariablesController < RbApplicationController
  unloadable

  #disable antiforgery for the backlog/sprint views
  skip_before_action :verify_authenticity_token

  # for index there's no @project
  # (eliminates the need of RbAllProjectsController)
  skip_before_action :load_project, :authorize, only: [:index]

  def index
    @context = params[:context]
    respond_to do |format|
      format.html { render_404 }
      format.js { render file: 'rb_server_variables/show.js.erb', layout: false }
    end
  end

  alias :project :index
  alias :sprint :index
end
