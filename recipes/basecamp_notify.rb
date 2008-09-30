require File.dirname(__FILE__) + '/../vendor/basecamp'

after 'deploy:symlink', 'basecamp:notify'

namespace :basecamp do
  set :basecamp_config do
    YAML.load(File.open('config/basecamp.yml'))['basecamp']
  end

  desc 'Post a new message to Basecamp containing the commit messages between the previous and the current deploy'
  task :notify do
    if exists?(:stage) and (basecamp_config['stages'].keys.include?(stage.to_s) || stage.to_sym != :production)
      domain = basecamp_config['domain']
      user = basecamp_config['user']
      password = basecamp_config['password']
      use_ssl = basecamp_config['use_ssl']
      project = basecamp_config['project_id']
      category = basecamp_config['stages'][stage.to_s] || basecamp_config['category_id']
      prefix = basecamp_config['prefix'] || 'Deploy'

      Basecamp.establish_connection!(domain, user, password, use_ssl)

      m = Basecamp::Message.new(:project_id => project)
      m.title = "#{prefix} - #{current_revision[0..7]}"
      m.body = grab_revision_log
      m.category_id = category

      m.save
    end
  end

  def grab_revision_log
    case scm.to_sym
      when :git
        %x( git log --pretty=format:"* #{ basecamp_config['git_log_format'] || "[%h, %an] %s"}" #{previous_revision}..#{current_revision} )
      when :subversion
        format_svn_log current_revision, previous_revision
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
      "* [#{logentry.attributes['revision']}, #{logentry.elements['author'].text}] <notextile>#{logentry.elements['msg'].text}</notextile>"
    end.join("\n")
  rescue
    %x( svn log --revision #{current_revision}:#{previous_revision} )
  end
end