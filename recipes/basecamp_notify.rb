require File.dirname(__FILE__) + '/../vendor/basecamp'

after 'deploy:symlink', 'basecamp:notify'

namespace :basecamp do
  set :basecamp_config do
    YAML.load(File.open('config/basecamp.yml'))['basecamp']
  end

  set :api_wrapper do
    Basecamp.new(basecamp_config['domain'], basecamp_config['user'], basecamp_config['password'])
  end

  desc 'Post a new message to Basecamp containing the commit messages between the previous and the current deploy'
  task :notify do
    api_wrapper.post_message basecamp_config['project_id'], {
      :title => "Deploy: #{application} [#{current_revision[0..6]}]",
      :body => grab_revision_log,
      :category_id => basecamp_config['category_id']
    }
  end

  desc 'Grab the revision log between the previous and the current deploy from the remote server'
  task :grab_revision_log do
    return case scm.to_sym
      when :git:
        %x( git log --pretty=format:"* [%h, %an] %s" #{previous_revision}..#{current_revision} )
      when :subversion:
        require 'rexml/document'
        format_svn_log(current_revision, previous_revision)
    end
  end
  
  def format_svn_log(current_revision, previous_revision)
    # Using REXML as it comes bundled with Ruby, would love to use Hpricot.
    # <logentry revision="2176">
    #   <author>jgoebel</author>
    #   <date>2006-09-17T02:38:48.040529Z</date>
    #   <msg>add delete link</msg>
    # </logentry>
    require 'rexml/document'
    xml = REXML::Document.new(%x( svn log --xml --revision #{current_revision}:#{previous_revision} ))
    xml.elements.collect('//logentry') do |logentry|
      "* [#{logentry.attributes['revision']}, #{logentry.elements['author'].text}] #{logentry.elements['msg'].text}"
    end
  rescue
    %x( svn log --revision #{current_revision}:#{previous_revision} )
  end
end