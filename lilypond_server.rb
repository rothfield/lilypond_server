require 'sinatra'
require 'json'

class LilypondServer < Sinatra::Application
  # Note: Need to install node and doremiscript tools :
  # Something like:
  # npm install doremi-script
  # Note: had to do the following:
  # sudo su ; cd /usr/bin ; ln -s /usr/local/bin/node
  #
  set :port,9292
  
  configure do
    mime_type :xml, 'text/plain'
    mime_type :ly, 'text/plain'
  end
  set :comp, "#{Dir.pwd}/public/compositions"
  set :doremi2ly, "/usr/local/bin/doremi2ly"
  set :lily2image, "#{Dir.pwd}/bin/lily2image"
  set :haml, :format => :html5
  
  def sanitize_filename(filename)
    name=filename.strip
     # NOTE: File.basename doesn't work right with Windows paths on Unix
     # get only the filename, not the whole path
     name.gsub!(/^.*(\\|\/)/, '')
  
     # Finally, replace all non alphanumeric, underscore 
     # or periods with underscore
     # name.gsub! /[^\w\.\-]/, '_'
     # Basically strip out the non-ascii alphabets too 
     # and replace with x. 
     # You don't want all _ :)
     name.gsub!(/[^0-9A-Za-z.\-]/, '_')
     return name
  end
  
  
  
  get '/' do
    "#{ENV["SHELL"]} - ENV[PATH] is   #{ ENV["PATH"]} - whoami is #{`whoami`} - pwd is #{`pwd`} - Usage: get /lilypond_to_jpg?fname=..&lilypond=...&doremi_source="
  end
  
  post '/lilypond_to_jpg' do
    comp=settings.comp
    dir=File.join('public','compositions')
    return "no fname param" if !params["fname"]
    return "no doremi_source param" if !params["doremi_source"]
    doremi_source=params["doremi_source"]
    musicxml_source=params["musicxml_source"]
    html_doc=params["html_doc"] || ""
    filename=params["fname"] || ""
    dont=params["dont_generate_staff_notation"] == "true" 
    simple_file_name=sanitize_filename(filename)
    fname="#{simple_file_name}"
    archive="#{simple_file_name}_#{Time.new.to_i}"
    
    fp= "#{comp}/#{fname}"
    archive="#{comp}/#{simple_file_name}_backup_#{Time.new.to_i}"
    # The -f stops rm from generating an error message
      File.open("#{archive}.doremi_script.txt", 'w') {|f| f.write(doremi_source) }
      File.open("#{fp}.doremi_script.txt", 'w') {|f| f.write(doremi_source) }
      File.open("#{fp}.xml", 'w') {|f| f.write(musicxml_source) }
      File.open("#{fp}.html", 'w') {|f| f.write(html_doc) }
      # I don't accept ly file from browser for security reasons. Run the 
      # parser on the server and save ly file. This should avoid evil
      # lilypond files
      doremi2ly_result= `cat #{fp}.doremi_script.txt | #{settings.doremi2ly} > #{fp}.ly 2>&1`  
      
      if !dont
      `rm -f #{fp}-page*png`
      result=`lilypond -o #{fp} #{fp}.ly  2>&1`
        #########################3
        #
        # Use lily2image to create better images for web
        #  http://code.google.com/p/lily2image/
        #  Requires lilypond 2.12.3  !!!!! and nbm
        #
        ########################
        
        result2= `#{settings.lily2image} -r=72 -f=jpg #{fp}.ly 2>&1`  
        result=result+result2
        # may create files like: bansuriv3-page1.jpeg
        # lilypond will create files like untitled_1319780034-page1.jpeg
        # if piece is long
        ####################################3
        #
        # COMBINE MULTI-PAGE jpegs if multiple pages
        # REQUIRES IMAGEMAGICK
        #
        ###################################
        page1="#{fp}-page1.jpeg"
        if File.file? page1
          puts "converting multiple pages using convert. #{fp}-page*.jpeg"
          `convert #{fp}-page*.jpeg -append #{fp}.jpeg`
        end
        `mv  #{fp}.jpeg #{fp}.jpg`
      error=false
      
      if $?.exitstatus > 0 # failed
        error=true
        fname=""
      end
      `rm #{fp}.ps`
      end
    fname = "/compositions/#{fname}.jpg"
    `cp #{fp}.ly #{comp}/last.ly`
    json={:error => error, 
     :fname => fname,
     :lilypond_output => result,
     :doremi2ly_output => doremi2ly_result
    }.to_json
  end
end 
