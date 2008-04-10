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
    if scm == 'git'
      return %x( git log --pretty=format:"* [%h, %an] %s" #{previous_revision}..#{current_revision} )
    else
      return %x( svn log --revision #{current_revision}:#{previous_revision} )
    end
  end
end