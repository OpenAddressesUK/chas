namespace :docker do
  desc "Update Docker image"
  task :update_image do
    docker_command = "docker #{ENV['DOCKER_TCP'] ? "-H #{ENV['DOCKER_TCP']}" : ""}"
    system("#{docker_command} pull opencorporates/morph-ruby")
    system("#{docker_command} pull openaustralia/morph-php")
    system("#{docker_command} pull opencorporates/morph-python")
    system("#{docker_command} pull openaustralia/morph-perl")
  end
end
