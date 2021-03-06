#!/bin/bash
function print_usage() {
  cat <<EOF
https://github.com/valda-z/jenkins-arm
Command
  $0
Arguments
  --vm_user_name|-u        [Required] : VM user name
  --git_url|-g             [Required] : Git URL with a Dockerfile in it's root
  --registry|-r            [Required] : Registry url targeted by the pipeline
  --registry_user_name|-ru [Required] : Registry user name
  --registry_password|-rp  [Required] : Registry password
  --repository|-rr         [Required] : Repository targeted by the pipeline
  --artifacts_location|-al            : Url used to reference other scripts/artifacts.
  --sas_token|-st                     : A sas token needed if the artifacts location is private.
EOF
}

function throw_if_empty() {
  local name="$1"
  local value="$2"
  if [ -z "$value" ]; then
    echo "Parameter '$name' cannot be empty." 1>&2
    print_usage
    exit -1
  fi
}

#defaults
artifacts_origin_location="https://raw.githubusercontent.com/Azure/azure-devops-utils/master/"
artifacts_location="https://raw.githubusercontent.com/valda-z/jenkins-arm/master/"
while [[ $# > 0 ]]
do
  key="$1"
  shift
  case $key in
    --vm_user_name|-u)
      vm_user_name="$1"
      shift
      ;;
    --git_url|-g)
      git_url="$1"
      shift
      ;;
    --registry|-r)
      registry="$1"
      shift
      ;;
    --registry_user_name|-ru)
      registry_user_name="$1"
      shift
      ;;
    --registry_password|-rp)
      registry_password="$1"
      shift
      ;;
    --repository|-rr)
      repository="$1"
      shift
      ;;
    --artifacts_location|-al)
      artifacts_location="$1"
      shift
      ;;
    --sas_token|-st)
      artifacts_location_sas_token="$1"
      shift
      ;;
    --help|-help|-h)
      print_usage
      exit 13
      ;;
    *)
      echo "ERROR: Unknown argument '$key' to script '$0'" 1>&2
      exit -1
  esac
done

throw_if_empty --vm_user_name $vm_user_name
throw_if_empty --git_url $git_url
throw_if_empty --registry $registry
throw_if_empty --registry_user_name $registry_user_name
throw_if_empty --registry_password $registry_password

if [ -z "$repository" ]; then
  repository="${vm_user_name}/myfirstapp"
fi

#install jenkins
curl --silent "${artifacts_location}jenkins/install_jenkins.sh${artifacts_location_sas_token}" | sudo bash -s

#install git
sudo apt-get install git --yes

#install docker if not already installed
if !(command -v docker >/dev/null); then
  sudo curl -sSL https://get.docker.com/ | sh
fi

#make sure jenkins has access to docker cli
sudo gpasswd -a jenkins docker
skill -KILL -u jenkins
sudo service jenkins restart

echo "Including the pipeline"
curl --silent "${artifacts_origin_location}/jenkins/add-docker-build-job.sh${artifacts_location_sas_token}" | sudo bash -s -- -j "http://localhost:8080/" -ju "admin" -g "${git_url}" -r "${registry}" -ru "${registry_user_name}"  -rp "${registry_password}" -rr "$repository" -sps "* * * * *" -al "$artifacts_location" -st "$artifacts_location_sas_token"