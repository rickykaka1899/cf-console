class SessionsController < ApplicationController
  skip_before_filter :require_login, :only => [:new, :create, :register_new, :register]

  def new
    if cookies[:cf_target_url]
      @target_url = cookies[:cf_target_url]
    else
      @target_url = CloudFoundry::Client::DEFAULT_TARGET
    end
    @available_targets = configatron.available_targets
    @selected_target = nil
    configatron.available_targets.each do |name, url|
      if url == @target_url
        @selected_target = url
        break
      end
    end
  end

  def create
    @email = params[:email]
    @password = params[:password]
    @cloud_service = params[:cloud_service]
    @target_args = params[:target_args]
    @target_url = params[:target_url]
    @remember_me = params[:remember_me]
    begin
      cf = cloudfoundry_client(@target_url)
      auth_token = cf.login(@email, @password)
      cookies[:email]=@email
    rescue
      auth_token = nil
    end

    if auth_token
      if @remember_me
        cookies.permanent[:cf_target_url] = @target_url
        cookies.permanent.signed[:cf_auth_token] = auth_token
      else
        cookies[:cf_target_url] = @target_url
        cookies.signed[:cf_auth_token] = auth_token
      end
      redirect_to root_url
    else
      flash.now[:alert] = I18n.t('sessions.controller.login_failed')
      @available_targets = configatron.available_targets
      @selected_target = nil
      configatron.available_targets.each do |name, url|
        if url == @cloud_service
          @selected_target = url
          break
        end
      end
      render "new"
    end
  end

  def destroy
    cookies.delete(:cf_auth_token)
    redirect_to root_url
  end

  def register_new
    render "register"
  end

  def register
    #@cf_client = cloudfoundry_client(cookies[:cf_target_url], cookies.signed[:cf_auth_token])
    @cf_client = cloudfoundry_client(cookies[:cf_target_url], cookies.signed[:cf_auth_token])
    @email = params[:email]
    @password = params[:password]
    @vpassword = params[:vpassword]
    if @email.blank?
      flash[:alert] = I18n.t('users.controller.email_blank')
    elsif @password.blank?
      flash[:alert] = I18n.t('users.controller.password_blank')
    elsif @password != @vpassword
      flash[:alert] = I18n.t('users.controller.passwords_match')
    else
      begin
        @email = @email.strip.downcase
        @password = @password.strip
        user = User.new(@cf_client)
        Rails.logger.info("-----------------------------------#{@cf_client}-----------------")

        begin
          Rails.logger.info("------------------------------0.1----------------------")
          user_info = user.find(@email)
          Rails.logger.info("--------------------------1--------------------------")
        rescue
          user_info = nil
        end
        if user_info.nil?
          @flag = user.create(@email, @password)
          Rails.logger.info("-------------------------flag-------------#{@flag}")
          user_info = user.find(@email)
          @new_user = [] << user_info
          Rails.logger.info("-----------------------2----------------------------")
          flash[:notice] = I18n.t('users.controller.user_created', :email => @email)
        else
          flash[:alert] = I18n.t('users.controller.already_exists')
          Rails.logger.info("----------------------------3333-----------------------")
        end
      rescue Exception => ex
        flash[:alert] = ex.message
      end
    end
    if @flag
      @cf_client.login(@email, @password)
      if @cf_client.logged_in?
        Rails.logger.info("----------------------------loggedin-----------------------")
      end
      respond_to do |format|
        Rails.logger.info("----------------------------redirect-----------------------")
        format.html { redirect_to root_url}
        format.js { flash.discard }
      end
    else
      render "register"
      Rails.logger.info("----------------------------render-----------------------")
    end
  end

  def updateuser
    render "updateuser"
  end


  def changepassword
    @email= cookies[:email]
    @new_password = params[:new_password]
    @confirmation_password = params[:confirmation_password]

    if @new_password.blank?
      flash.now[:alert] = I18n.t('users.controller.password_blank')
      render "updateuser"
    elsif @confirmation_password.blank?
      flash.now[:alert] = I18n.t('users.controller.password_blank')
      render "updateuser"
    elsif @new_password!= @confirmation_password
      flash.now[:alert] = I18n.t('users.controller.passwords_match')
      render "updateuser"
    else
      begin
        @email = @email.strip.downcase
        @password = @new_password.strip
        user = User.new(@cf_client)
        user.update(@email, @new_password)
      rescue Exception => ex
        flash[:alert] = ex.message
      end
      respond_to do |format|
        format.html { redirect_to root_url }
        format.js { flash.discard }
      end
    end


  end

end
