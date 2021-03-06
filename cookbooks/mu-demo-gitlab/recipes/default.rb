#
# Cookbook Name:: demo
# Recipe:: gitlab
#
# Copyright:: Copyright (c) 2017 eGlobalTech, Inc., all rights reserved
#
# Licensed under the BSD-3 license (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License in the root of the project or at
#
#     http://egt-labs.com/mu/LICENSE.html
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# require 'securerandom'
include_recipe 'chef-vault'

node.normal['gitlab']['is_server'] = true

# GENERATE AND SET RUNNER TOKEN AND ROOT PASSWORD
if node['gitlab'].key?('runner_token') and !node['gitlab']['runner_token'].empty?
    runner_token = node['gitlab']['runner_token']
elsif ENV['GITLAB_SHARED_RUNNERS_REGISTRATION_TOKEN']
    runner_token = ENV['GITLAB_SHARED_RUNNERS_REGISTRATION_TOKEN']
else
    runner_token = SecureRandom.urlsafe_base64
end

if node['gitlab'].key?('gitlab_root_pwd') and !node['gitlab']['gitlab_root_pwd'].empty?
    gitlab_root_pwd = node['gitlab']['gitlab_root_pwd']
elsif ENV['GITLAB_ROOT_PASSWORD']
    gitlab_root_pwd = ENV['GITLAB_ROOT_PASSWORD']
else
    gitlab_root_pwd = SecureRandom.urlsafe_base64
end

# SET ENV VARIABLES TO PASS TO GITLAB AND TO THE GITLAB RUNNER
ENV['GITLAB_ENDPOINT'] = node['gitlab']['endpoint']
ENV['GITLAB_RUNNER_ENDPOINT'] = node['gitlab']['runner_endpoint']
ENV['GITLAB_ROOT_PASSWORD'] = gitlab_root_pwd
ENV['GITLAB_SHARED_RUNNERS_REGISTRATION_TOKEN'] = runner_token

node.normal['gitlab']['runner_token'] = runner_token
node.normal['gitlab']['gitlab_root_pwd'] = gitlab_root_pwd
node.save # ~FC075

include_recipe 'omnibus-gitlab::default'

execute 'Reconfigure Gitlab' do
    command "gitlab-ctl reconfigure"
    not_if "gitlab-ctl status"
    ignore_failure true
    notifies :run, 'execute[Restart Gitlab]', :immediately
end

execute 'Restart Gitlab' do
    command "gitlab-ctl restart"
    action :nothing
end

firewall 'default' do
    action :nothing
end

firewall_rule 'Open Gitlab Ports' do
    port     [80, 8080]
    command  :allow
    notifies :restart, 'firewall[default]', :immediately
end