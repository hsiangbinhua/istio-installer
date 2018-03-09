#!/bin/bash

printHelp() {
  echo -e << EOF "SWS and Istio install script on OpenShift
  Description: This script
  *
  Usage:
  $0
  variable USR running on user's home directory, by default 'hudson' will be taken
  variable REMOVE_ISTIO when set 'true' it will remove Istio from OC
  variable INSTALL_ISTIO when set 'true' it will install Istio on OC
  variable INSTALL_BOOKINFO when set 'true', it will instakk BookInfo application, VALID when INSTALL_ISTIO is set 'true'
  variable REMOVE_SWS when set 'true' it will remove SWS from OC
  variable INSTALL_SWS when set 'true' it will install SWS on OC
  variable ISTIO_VERSION is the version of Istio to be installed, by default latest version will be used
  variable DOCKER_USERNAME username to login into Docker hub
  variable DOCKER_PASSWORD docker password
  variable OS_HOSTNAME Openshift hostname, default 'localhost'
  variable OS_PORT Openshift port, default '8443'
  variable OS_TOKEN Openshift token, will be used token login if given, otherwise credentials will be used
  variable OS_USERNAME Openshift login, default 'admin'
  variable OS_PASSWORD Openshift password, default 'redhat' "
EOF
  exit 1
}

if [ "$1" == "--help" ]; then
  printHelp
fi

USR=${USR:="hudson"}

host=`hostname`

GIT_REPO=${GIT_REPO:-"https://github.com/swift-sunshine/swscore.git"}
GIT_BRANCH=${GIT_BRANCH:-"master"}
GOPATH="/home/${USR}/go"
ROOT_DEST="${GOPATH}/src/github.com/swift-sunshine"
SWS_DEST="${ROOT_DEST}/swscore"
ISTIO_DEST="${ROOT_DEST}/istio-*"

ISTIO_VERSION=${ISTIO_VERSION:-""}
OS_HOSTNAME=${OS_HOSTNAME:-"localhost"}
OS_PORT=${OS_PORT:-"8443"}
OS_TOKEN=${OS_TOKEN:-""}
OS_USERNAME=${OS_USERNAME:-"admin"}
OS_PASSWORD=${OS_PASSWORD:-"redhat"}

DOCKER_USERNAME=${DOCKER_USERNAME:-""}
DOCKER_PASSWORD=${DOCKER_PASSWORD:-""}

function check_os_login() {
    if [ ! -z "$OS_TOKEN" ]; then
       echo "OC login via token"
       oc login ${OS_HOSTNAME}:${OS_PORT} --token=${OS_TOKEN} --insecure-skip-tls-verify=true  1> /dev/null
    else
       echo "OC login via credentials"
       oc login ${OS_HOSTNAME}:${OS_PORT} -u ${OS_USERNAME} -p ${OS_PASSWORD} --insecure-skip-tls-verify=true 1> /dev/null
    fi
    # make sure we are logged in first
    oc whoami 1> /dev/null
    if [ "$?" != 0 ]; then
      echo "Please log in to OpenShift using 'oc login'"
      exit 1
    fi
}

function check_docker_login() {
    echo "Check Docker Login"
    docker login --username ${DOCKER_USERNAME} --password ${DOCKER_PASSWORD}

    export DOCKER_USER=`docker info | grep ${DOCKER_USERNAME}`
    if [ -z "$DOCKER_USER" ]; then
	echo "Please login to Docker"
	exit 1
    fi
}

function check_dependencies() {
    echo "Check dependency packages"
    npm help  1> /dev/null
    if [ "$?" != 0 ]; then
      echo "Please make sure npm is installed"
      exit 1
    fi
}

function clean_docker_images() {
  echo "Delete all containers"
  docker rm $(docker ps -a | grep sws | awk '{print $1}') > /dev/null 2>&1
  echo "Delete all images"
  docker rmi -f $(docker images | grep sws | awk '{print $3}') > /dev/null 2>&1
}

function prepare_istio() {
   echo  "Downloading Istio"

   rm -r -f $ISTIO_DEST

   mkdir -p ${ROOT_DEST}
   cd $ROOT_DEST

   # download istio
   curl -L https://git.io/getLatestIstio | ISTIO_VERSION=${ISTIO_VERSION} sh - 1> /dev/null

   echo "Istio Downloaded"
}

function clean_istio() {
    echo "Cleaning Istio"

    prepare_istio

    cd $ISTIO_DEST

    oc delete -f install/kubernetes/istio.yaml > /dev/null 2>&1

    oc delete --ignore-not-found=true serviceaccounts "istio-ingress-service-account" > /dev/null 2>&1

    oc delete --ignore-not-found=true serviceaccounts "istio-pilot-service-account" > /dev/null 2>&1

    oc delete --ignore-not-found=true serviceaccounts "istio-egress-service-account" > /dev/null 2>&1

    oc delete --ignore-not-found=true serviceaccounts "istio-grafana-service-account" > /dev/null 2>&1

    oc delete --ignore-not-found=true serviceaccounts "istio-prometheus-service-account" > /dev/null 2>&1

    export ISTIO_PROJECT=`oc get project | grep istio`

    if [ ! -z "$ISTIO_PROJECT" ]; then
       sleep 60
    fi

    export ISTIO_PROJECT=`oc get project | grep istio`
    if [ ! -z "$ISTIO_PROJECT" ]; then
       sleep 120
    fi

    echo "Istio Cleaned"
}

function install_istio() {

    echo "Installing Istio System"

    cd $ISTIO_DEST

    oc new-project istio-system 1> /dev/null

    oc project istio-system 1> /dev/null

    oc adm policy add-scc-to-user anyuid -z istio-ingress-service-account 1> /dev/null

    oc adm policy add-scc-to-user privileged -z istio-ingress-service-account 1> /dev/null

    oc adm policy add-scc-to-user anyuid -z istio-egress-service-account 1> /dev/null

    oc adm policy add-scc-to-user privileged -z istio-egress-service-account 1> /dev/null

    oc adm policy add-scc-to-user anyuid -z istio-pilot-service-account 1> /dev/null

    oc adm policy add-scc-to-user privileged -z istio-pilot-service-account 1> /dev/null

    oc adm policy add-scc-to-user anyuid -z default 1> /dev/null

    oc adm policy add-scc-to-user privileged -z default 1> /dev/null

    oc adm policy add-cluster-role-to-user cluster-admin -z default 1> /dev/null

    oc adm policy add-scc-to-user anyuid -z istio-grafana-service-account 1> /dev/null

    oc adm policy add-scc-to-user privileged -z istio-pilot-service-account 1> /dev/null

    oc adm policy add-scc-to-user anyuid -z prometheus 1> /dev/null

    oc adm policy add-scc-to-user privileged -z istio-prometheus-service-account 1> /dev/null


    oc apply -f install/kubernetes/istio.yaml 1> /dev/null

    oc expose svc istio-ingress 1> /dev/null

    oc create -f install/kubernetes/addons/prometheus.yaml 1> /dev/null

    oc create -f install/kubernetes/addons/grafana.yaml 1> /dev/null

    oc create -f install/kubernetes/addons/servicegraph.yaml 1> /dev/null

    oc process -f https://raw.githubusercontent.com/jaegertracing/jaeger-openshift/master/all-in-one/jaeger-all-in-one-template.yml | oc create -f - 1> /dev/null

    oc expose svc servicegraph 1> /dev/null

    oc expose svc grafana 1> /dev/null

    oc expose svc prometheus 1> /dev/null

    echo "Istio Installed"
}

function install_bookinfo() {
   echo "Installing the BookInfo demo"
   
   cd $ISTIO_DEST

   oc project istio-system 1> /dev/null

   oc adm policy add-scc-to-user anyuid -z default 1> /dev/null
   oc adm policy add-scc-to-user privileged -z default 1> /dev/null

   bin/istioctl kube-inject -f samples/bookinfo/kube/bookinfo.yaml | oc apply -f - 1> /dev/null

   oc expose svc productpage 1> /dev/null

   PRODUCTPAGE=$(oc get route productpage -o jsonpath='{.spec.host}{"\n"}')
   echo "Generating workload for the application"
   for ((i=1;i<=100;i++)); do  curl -o /dev/null -s $PRODUCTPAGE/productpage ; done
}

function clean_swscore() {
    echo "Clean SWS Core"

    rm -r -f ${SWS_DEST}

    rm -r -f ${GOPATH}/bin/*

    echo "SWS Core Cleaned"
}

function prepare_swscore() {
    echo "Prepare SWS Core"

    clean_swscore

    mkdir -p ${ROOT_DEST}

    git clone -b ${GIT_BRANCH} ${GIT_REPO} ${SWS_DEST} 1> /dev/null

    export GOPATH

    export PATH=${PATH}:${GOPATH}/bin

    echo $PATH

    cd ${SWS_DEST}

    find . -type f -print0 | xargs -0 sed -i 's@jmazzitelli@swsqe@'

    find . -type f -print0 | xargs -0 sed -i 's@ dev$@ latest@'

    oc login ${OS_HOSTNAME}:${OS_PORT} -u ${OS_USERNAME} -p ${OS_PASSWORD} 1> /dev/null

    echo "SWS Core Prepared"
}

function build_swscore() {
    echo "Build SWS Core"

    cd ${SWS_DEST}

    make dep-install 1> /dev/null

    make build 1> /dev/null

    make docker 1> /dev/null

    echo "Docker tag"

    IMAGE_ID=`docker images | grep sws | awk 'NR==1{print $3}'`

    docker tag ${IMAGE_ID} docker.io/swsqe/sws:latest 1> /dev/null

    docker push docker.io/swsqe/sws:latest 1> /dev/null

    echo "SWS Core Built"
}

function deploy_sws() {
    echo "Deploy SWS on Openshift"

    cd ${SWS_DEST}

    make openshift-deploy 1> /dev/null

    echo "SWS Deployed"
}

function undeploy_sws() {
    echo "Undeploy SWS on Openshift"

    cd ${SWS_DEST}

    make openshift-undeploy 1> /dev/null

    echo "SWS Undeployed"
}

check_os_login

check_dependencies


if [ ! -z ${INSTALL_ISTIO} ] && [ ${INSTALL_ISTIO} == "true" ]
then
  clean_istio

  install_istio

  if [ ! -z ${INSTALL_BOOKINFO} ] && [ ${INSTALL_BOOKINFO} == "true" ]
  then
     install_bookinfo
  fi
fi

if [ ! -z ${REMOVE_SWS} ] && [ ${REMOVE_SWS} == "true" ]
then

  prepare_swscore

  undeploy_sws

  clean_docker_images
fi

if [ ! -z ${INSTALL_SWS} ] && [ ${INSTALL_SWS} == "true" ]
then

  prepare_swscore

  undeploy_sws

  clean_docker_images

  sleep 10

  build_swscore

  deploy_sws

fi
