def generate_question
  if ENV['RACK_ENV'] == 'test'
    question_first_number = 1
    question_last_number = 1
  else
    question_first_number = rand 5
    question_last_number = rand 5
  end
  session[:question_answer] = (question_first_number + question_last_number).to_s
  [question_first_number, question_last_number]
end

def dashboard_if_signed_in
  redirect '/dashboard' if signed_in?
end

def dashboard_init
  if params[:dir] && params[:dir][0] != '/'
    params[:dir] = '/'+params[:dir]
  end

  if !File.directory?(current_site.files_path(params[:dir]))
    redirect '/dashboard'
  end

  @dir = params[:dir]
  @file_list = current_site.file_list @dir
end

def require_login_ajax
  halt 'You are not logged in!' unless signed_in?
  halt 'You are banned.' if current_site.is_banned? || parent_site.is_banned?
end

def csrf_safe?
  csrf_token == params[:csrf_token] || csrf_token == request.env['HTTP_X_CSRF_TOKEN']
end

def csrf_token
   session[:_csrf_token] ||= SecureRandom.base64(32)
end

def require_login
  redirect '/' unless signed_in?
  if session[:banned] || current_site.is_banned || parent_site.is_banned
    session[:id] = nil
    session[:banned] = true
    redirect '/'
  end
end

def signed_in?
  !session[:id].nil?
end

def current_site
  return nil if session[:id].nil?
  @_site ||= Site[id: session[:id]]
end

def parent_site
  return nil if current_site.nil?
  current_site.parent? ? current_site : current_site.parent
end

def require_unbanned_ip
  if session[:banned] || Site.banned_ip?(request.ip)
    session[:id] = nil
    session[:banned] = true
    flash[:error] = 'Site creation has been banned due to ToS violation/spam. '+
    'If you believe this to be in error, <a href="/contact">contact the site admin</a>.'
    return {result: 'error'}.to_json
  end
end

def title
  out = "Neocities"
  return out                  if request.path == '/'
  return "#{out} - #{@title}" if @title
  "#{out} - #{request.path.gsub('/', '').capitalize}"
end

def encoding_fix(file)
  begin
    Rack::Utils.escape_html file
  rescue ArgumentError => e
    return Rack::Utils.escape_html(file.force_encoding('BINARY')) if e.message =~ /invalid byte sequence in UTF-8/
    fail
  end
end

def send_confirmation_email(site=current_site)
  EmailWorker.perform_async({
    from: 'web@neocities.org',
    reply_to: 'contact@neocities.org',
    to: site.email,
    subject: "[Neocities] Confirm your email address",
    body: Tilt.new('./views/templates/email_confirm.erb', pretty: true).render(self, site: site)
  })
end