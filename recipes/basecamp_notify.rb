require File.dirname(__FILE__) + '/../vendor/basecamp'

after 'deploy:symlink', 'basecamp:notify'

namespace :basecamp do
  set :config do
    YAML.load(File.open('config/basecamp.yml'))['basecamp']
  end

  desc 'Post a new message to Basecamp containing the commit messages between the previous and the current deploy'
  task :notify do
    if exists?(:stage) and (config['stages'].keys.include?(stage.to_s) || stage.to_sym != :production)
      Basecamp.establish_connection!(config['domain'], config['user'], config['password'], config['use_ssl'] || false)
      msg = config['ask_msg'] ? Capistrano::CLI.ui.ask("Deployment notice (press enter for none):") : nil
      
      m = Basecamp::Message.new(:project_id => config['project_id'])
      m.title = parse_title(config['title_format'])
      m.body = msg ? msg + "\n\n" + grab_revision_log : grab_revision_log
      m.category_id = config['stages'][stage.to_s] || config['category_id']
      m.save
    end
  end

  def grab_revision_log
    case scm.to_sym
      when :git
        %x( git log --pretty=format:"* #{ config['git_log_format'] || "[%h, %an] %s"}" #{previous_revision}..#{current_revision} )
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
  
  def parse_title(title_string)
    prefix = config['prefix'] || 'Deploy'
    return "#{prefix} - #{current_revision[0..7]}" unless title_string
    title_string.sub('%p', prefix).sub('%a', application).sub('%r', current_revision[0..7]).sub('%s', stage.to_s)
  end
end