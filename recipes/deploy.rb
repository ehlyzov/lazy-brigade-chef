user = node['app-user']
domain = node["app-domain"]
environment = node['environment']
repo_url = node['repo-url']
app_name = domain.split('.', 2)[0]
app_dir = "/srv/#{app_name}"

deploy_dir = "/home/#{user}/deploy"

['', 'config', 'deploy'].inject(deploy_dir) do |absolute_path, relative_path|
  File.join(absolute_path, relative_path).tap do |path|
    directory path do  
      owner user
      group user
    end
  end
end

cookbook_file "Gemfile" do
  path deploy_dir + '/Gemfile'
  owner user
  group user
end

cookbook_file "Capfile" do
  path deploy_dir + '/Capfile'
  owner user
  group user
end

template File.join(deploy_dir, 'config', 'deploy.rb') do
  owner user
  group user
  source "deploy.rb.erb"
  variables({
    app_name: app_name,
    repo_url: repo_url,
    app_dir: app_dir,
    user: user,
    rbenv_ruby: node['rbenv']['user_installs'][0]['global']
  })
  action :nothing
  subscribes :create, "directory[#{deploy_dir}/config]"
end

template File.join(deploy_dir, 'config', 'deploy', environment + '.rb') do
  owner user
  group user
  source "deploy_stage.erb"
  variables({
    domain: domain,
    user: user
  })
  action :nothing
  subscribes :create, "directory[#{deploy_dir}/config/deploy]"
end
