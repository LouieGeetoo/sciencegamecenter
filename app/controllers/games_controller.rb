class GamesController < ApplicationController

  #force_ssl                       except: [:index, :show]
  before_filter :signed_in_user,  except: [:index, :show]
  before_filter :admin_user,      except: [:index, :show]

  def index
    category_types = [:subject, :platform, :cost, :intended_for, :developer_type]
    @any_category_defined = any_category_defined?
    if @any_category_defined
      if admin?
        @games = Game.tagged_with(category_types.map {|c| params[c]}.join(", ")).paginate(page: params[:page], per_page: 10)
      else
        @games = Game.enabled.tagged_with(category_types.map {|c| params[c]}.join(", ")).paginate(page: params[:page], per_page: 10)
      end
    else
      if admin?
        @games = Game.paginate(page: params[:page], per_page: 10)
      else
        @games = Game.enabled.paginate(page: params[:page], per_page: 10)
      end
    end
  end

  def show
    @game = Game.find(params[:id])

    if @game.disabled? && !admin?
      flash[:failure] = "Swiper, no swiping! Sorry, you aren't able to view that page unless you're a site administrator."
      redirect_to root_path
    end

    @player_reviews = @game.actual_player_reviews
    @expert_reviews = @game.expert_reviews
    @authoritative_reviews = @game.authoritative_reviews
    @player_review = PlayerReview.new

    if request.path != game_path(@game)
      redirect_to @game, status: :moved_permanently
    end
  end

  def new
    @game = Game.new
  end

  def create
    @game = Game.new(params[:game])
    if @game.save
      flash[:success] = "Game #{@game.title} created."
      redirect_to @game
    else
      render 'new'
    end
  end

  def edit
    @game = Game.find(params[:id])
  end

  def update
    @game = Game.find(params[:id])
    if @game.update_attributes(params[:game])
      flash[:success] = view_context.sanitize "Game <i>#{@game.title}</i> updated."
      redirect_to @game
    else
      render 'edit'
    end
  end

  def destroy
    game = Game.find(params[:id])
    Game.find(params[:id]).destroy
    flash[:success] = view_context.sanitize "Game <i>#{game.title}</i> and all its reviews and comments have been destroyed now and forever."
    redirect_to games_path
  end

  private

  def any_category_defined?
    !params[:platform].blank? || !params[:subject].blank? || !params[:cost].blank? || !params[:intended_for].blank? || !params[:developer_type].blank?
  end
end
