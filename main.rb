
require 'rubygems'
require 'tmail'
require 'sinatra'
set :app_file, __FILE__


#$LOAD_PATH.unshift File.dirname(__FILE__) + '/vendor/sequel'
require 'dm-core'


configure do
  #Sequel.connect(ENV['DATABASE_URL'] || 'sqlite://blog.db')
  DataMapper.setup(:default, "appengine://auto")

  require 'ostruct'
  Blog = OpenStruct.new(
                        :title => 'Try It Till Less Enthusiasm',
                        :author => 'Li Ren',
                        :url_base => 'http://localhost:4567/',
                        :admin_password => 'changeme',
                        :admin_cookie_key => 'scanty_admin',
                        :publish_mail => 'from@gmail.com',
                        :admin_cookie_value => '51d6d39d83dadfewfjd2idm',
                        :disqus_shortname => ''
                        )
end

error do
  e = request.env['sinatra.error']
  puts e.to_s
  puts e.backtrace.join("\n")
  "Application error"
end

$LOAD_PATH.unshift(File.dirname(__FILE__) + '/lib')
require 'post'
require 'gaelog'

helpers do
  def admin?
    request.cookies[Blog.admin_cookie_key] == Blog.admin_cookie_value
  end

  def auth
    stop [ 401, 'Not authorized' ] unless admin?
  end
end

layout 'layout'

### Public

get '/' do
  posts = Post.all(:order => [:created_at.desc], :limit => 10)
  erb :index, :locals => { :posts => posts }, :layout => false
end

get '/past/:year/:month/:day/:slug/' do
  post = Post.first(:slug => params[:slug])
  halt 404, "Page not found"  unless post
  @title = post.title
  erb :post, :locals => { :post => post }
end

get '/past/:year/:month/:day/:slug' do
  redirect "/past/#{params[:year]}/#{params[:month]}/#{params[:day]}/#{params[:slug]}/", 301
end

get '/past' do
  posts = Post.all(:order=> [:created_at.desc])
  @title = "Archive"
  erb :archive, :locals => { :posts => posts }
end

get '/past/tags/:tag' do
  tag = params[:tag]
  posts = Post.all(:tags => tag,  :limit => 30)
  @title = "Posts tagged #{tag}"
  erb :tagged, :locals => { :posts => posts, :tag => tag }
end

get '/feed' do
  @posts = Post.all(:order => [:created_at.desc], :limit => 20)
  content_type 'application/atom+xml', :charset => 'utf-8'
  builder :feed
end

get '/rss' do
  redirect '/feed', 301
end

def gaelog(name, info)
  l = GaeLog.new
  l.info = info
  l.name = name
  l.created_at = Time.now

  l.save
end

post '/_ah/mail/:to' do
  m = TMail::Mail.parse(request.env["rack.input"].read)
  return if m.from.to_s != Blog.publish_mail
  return if m.subject.nil?
  
  title, tags =  m.subject.split('|')
  tags ||= ' '
  
  c = m.parts.find {|p| p.content_type =~ /plain/ } if m.multipart?
  c ||= m

  post = Post.new :title => title, :tags => tags.squeeze(' ').split(/[ ,]/), :body => c.body, :created_at => Time.now, :slug => Post.make_slug(title)
  post.save
  
end

### Admin

get '/auth' do
  erb :auth
end

post '/auth' do
  response.set_cookie(Blog.admin_cookie_key, Blog.admin_cookie_value) if params[:password] == Blog.admin_password
  redirect '/'
end

get '/posts/new' do
  auth
  erb :edit, :locals => { :post => Post.new, :url => '/posts' }
end

post '/posts' do
  auth
  post = Post.new :title => params[:title], :tags => params[:tags].squeeze(' ').split(/[ ,]/), :body => params[:body], :created_at => Time.now, :slug => Post.make_slug(params[:title])
  post.save
  redirect post.url
end

get '/past/:year/:month/:day/:slug/edit' do
  auth
  post = Post.first(:slug => params[:slug])
  stop [ 404, "Page not found" ] unless post
  erb :edit, :locals => { :post => post, :url => post.url }
end

post '/past/:year/:month/:day/:slug/' do
  auth
  post = Post.first(:slug => params[:slug])
  stop [ 404, "Page not found" ] unless post
  post.title = params[:title]
  post.tags = params[:tags].squeeze(' ').split(/[ ,]/)
  post.body = params[:body]
  post.save
  redirect post.url
end

