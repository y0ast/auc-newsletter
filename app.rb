require 'rubygems'
require 'sinatra'
require 'data_mapper'
require 'builder'
require 'pony'
require 'sinatra/config_file'

config_file 'config.yml'

configure :production do
      require 'newrelic_rpm'
end

DataMapper.setup(:default, ENV['HEROKU_POSTGRESQL_OLIVE_URL'] || settings.db)

class Article
    include DataMapper::Resource

    property :id, Serial
    property :title, String, :required => true
    property :content, Text, :required => true
    property :poster, String, :required => true
    property :email, String, :required => true
    property :created_at, DateTime
    property :confirmed, Boolean, :default => false
    property :checked, Boolean, :default => false
end

DataMapper.finalize
DataMapper.auto_upgrade!

get '/' do
    @article = Article.new
    erb :"article"
end

get '/article/confirm/:id' do
   if Article.get(params[:id]).update(:confirmed => true)
       @message = "Your article is succesfully submitted, it will be available in the next weekly" 
       erb :"message"
   else 
       redirect '/'
   end
end

get '/article/check/:id' do
   if Article.get(params[:id]).update(:checked => true)
       redirect '/list'
   else 
       redirect '/'
   end
end

get '/article/delete/:id' do
   if Article.get(params[:id]).destroy
       redirect '/list'
   else 
       redirect '/'
   end
end

get '/list' do
    @articles = Article.all(:checked => false, :confirmed => true)
    erb :"show"
end

post '/article' do
    @article = Article.new(params[:article])
    emails = ["@auc.nl", "@student.auc.nl","@aucsa.nl"]

    if @article.email == "info@aucsa.nl"
        @article.confirmed = true
        if @article.save
            puts Article.get(params[:article][:id]).inspect
            @message = "Your article is received and confirmed."
            erb :"message"
         else
             @message = "Please fill out all fields, your aucsa email is recognized correctly."
             erb :"error"
        end
    elsif @article.save && emails.any? {|email| @article.email.include?(email)}
        address = ENV['SENDGRID_USERNAME'] ? 'smtp.sendgrid.net' : 'smtp.gmail.com'
        Pony.mail({
            :to => params[:article][:email],
            :from => "feedback@aucsa.nl",
            :via => :smtp,
            :via_options => {
            :address              => address,
            :port                 => '587',
            :enable_starttls_auto => true,
            :authentication       => :plain,
            :user_name            => ENV['SENDGRID_USERNAME'] || settings.username, 
            :password             => ENV['SENDGRID_PASSWORD'] || settings.password,
            :domain               => "heroku.com" # the HELO domain provided by the client to the server
        },
            :subject => 'Please confirm your post', :body => 'Please follow this link: ' + request.url + "/confirm/#{@article.id} to confirm your news article"
        })
        @message = "Please check your email to confirm your article"
        erb :"message"
    else
        @message = "Something went wrong! Please use your student email (@student.auc.nl) and fill out all fields (mind the max length of the title field). If you don't have a student email please contact AUCSA (info@aucsa.nl)."
        erb :"error"
    end
end

get '/rss.xml' do
    @articles = Article.all(:order => [:id.desc], :confirmed => true, :checked => true)
    builder do |xml|
        xml.instruct! :xml, :version => '1.0'
        xml.rss :version => "2.0" do
            xml.channel do
                xml.title "Student newsletter"
                xml.description "The AUC student run weekly!"
                xml.link request.url

                @articles.each do |article|
                    xml.item do
                        xml.title article.title
                        xml.description article.content
                        xml.author article.poster
                        xml.pubDate Time.parse(article.created_at.to_s).rfc822()
                    end
                end
            end
        end
    end
end
